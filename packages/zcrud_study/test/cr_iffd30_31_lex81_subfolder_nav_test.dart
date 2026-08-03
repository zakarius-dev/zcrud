/// CR-IFFD-30 / CR-IFFD-31 / CR-LEX-81 — navigation de sous-dossiers.
///
/// * **CR-IFFD-31** : l'`itemBuilder` doit pouvoir savoir de quel côté du seuil
///   (600 dp) il est rendu, SANS 4ᵉ paramètre et SANS `LayoutBuilder` (fermé par
///   le `ChoiceChip` du sélecteur compact) ⇒ `ZSubfolderLayoutMode.of(context)`.
/// * **CR-IFFD-30** : slot `sidebarHeader`, masqué AUTOMATIQUEMENT au repli.
/// * **CR-LEX-81** : `ZSubfolderSidebar.width` n'est **pas** une contrainte de
///   layout — garde comportementale + garde STRUCTURELLE (le code et la dartdoc
///   ne peuvent plus diverger sans rougir).
///
/// Accès `dart:io` pour la garde structurelle ⇒ `@TestOn('vm')`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

const String _kHeaderKey = 'cr30:header';
const String _kTileKey = 'cr31:tile';

/// Spec de navigation locale (le harnais partagé n'expose pas `sidebarHeader`).
ZSubfolderNavSpec _nav({
  Widget? sidebarHeader,
  ZSubfolderItemBuilder? itemBuilder,
  // CR-IFFD-40 — `null` ⇒ DÉFAUT DE PRODUCTION (jamais recopié en dur ici).
  ZSubfolderNarrowMode? narrowMode,
}) {
  return ZSubfolderNavSpec(
    subfolders: refs(n: 2),
    allSubfoldersLabel: kAllLabel,
    sidebarHeader: sidebarHeader,
    itemBuilder: itemBuilder,
    narrowMode: narrowMode ?? kProductionDefaultNarrowMode,
    collapseLabel: kCollapseLabel,
    expandLabel: kExpandLabel,
    resizeLabel: kResizeLabel,
    initialSidebarWidth: 320,
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // CR-IFFD-31 — le mode de mise en page est lisible depuis le `context`
  // ---------------------------------------------------------------------------
  group('CR-IFFD-31 — ZSubfolderLayoutMode lisible des DEUX côtés du seuil', () {
    /// Enregistre les modes RÉELLEMENT observés par le builder pendant le rendu.
    ///
    /// `maybeOf` (et NON `of`) : le repli documenté de `of` sur `compact`
    /// masquerait l'absence de scope côté compact — la garde resterait verte
    /// sous sa propre régression.
    ZSubfolderItemBuilder recorder(Set<ZSubfolderLayoutMode?> seen) {
      return (context, ref, selected) {
        seen.add(ZSubfolderLayoutMode.maybeOf(context));
        return Text(ref.label);
      };
    }

    testWidgets('≥ 600 dp (sidebar) ⇒ le builder observe `sidebar`', (
      tester,
    ) async {
      // Vraie fenêtre pompée : un `SizedBox` serait écrasé par la surface de
      // test (800 dp) et ne franchirait pas le seuil.
      await setScreen(tester, 900, 800);
      final seen = <ZSubfolderLayoutMode?>{};
      await pumpDetail(tester, nav: _nav(itemBuilder: recorder(seen)));

      expect(find.byType(ZSubfolderSidebar), findsOneWidget);
      // Observation de RENDU, pas une assertion de type : le builder a bien été
      // invoqué sous le scope de la sidebar.
      // Non-null EXIGÉ : `null` = scope absent (régression), pas un repli.
      expect(seen, <ZSubfolderLayoutMode?>{ZSubfolderLayoutMode.sidebar});
    });

    testWidgets('< 600 dp (compact) ⇒ le builder observe `compact`', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      final seen = <ZSubfolderLayoutMode?>{};
      await pumpDetail(
        tester,
        // CR-IFFD-40 — surface NOMMÉE : cette garde vise la rangée de puces,
        // qui n'est plus le défaut. Le scope de la surface par DÉFAUT est gardé
        // par `cr_iffd40_subfolder_selector_test.dart`.
        nav: _nav(
          itemBuilder: recorder(seen),
          narrowMode: ZSubfolderNarrowMode.compact,
        ),
      );

      expect(find.byType(ZSubfolderCompactSelector), findsOneWidget);
      // GARDE MORDANTE : scope absent — ou posé SOUS le `ChoiceChip`, donc
      // hors de portée du builder — ce set vaudrait `{null}` et rougirait.
      expect(seen, <ZSubfolderLayoutMode?>{ZSubfolderLayoutMode.compact});
    });

    testWidgets('hors surface zcrud : `maybeOf` = null, `of` = compact', (
      tester,
    ) async {
      ZSubfolderLayoutMode? maybe;
      late ZSubfolderLayoutMode fallback;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              maybe = ZSubfolderLayoutMode.maybeOf(context);
              fallback = ZSubfolderLayoutMode.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(maybe, isNull);
      // Repli DOCUMENTÉ : `compact` est le seul mode sûr sous largeur non bornée.
      expect(fallback, ZSubfolderLayoutMode.compact);
    });
  });

  // ---------------------------------------------------------------------------
  // CR-IFFD-31 — le cas d'usage RÉEL qui a échoué chez IFFD : un `ListTile`
  // ---------------------------------------------------------------------------
  group('CR-IFFD-31 — un `ListTile` piloté par le mode rend des DEUX côtés', () {
    /// Builder d'hôte RÉALISTE : `ListTile` (largeur bornée requise) côté
    /// sidebar, contenu auto-dimensionné côté compact.
    Widget modeAware(BuildContext context, ZSubfolderRef ref, bool selected) {
      return switch (ZSubfolderLayoutMode.of(context)) {
        ZSubfolderLayoutMode.sidebar => ListTile(
          key: const ValueKey<String>(_kTileKey),
          title: Text(ref.label),
        ),
        ZSubfolderLayoutMode.compact => Text(ref.label),
      };
    }

    testWidgets('sidebar (900 dp) : `ListTile` rendu, AUCUNE exception', (
      tester,
    ) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester, nav: _nav(itemBuilder: modeAware));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>(_kTileKey)), findsWidgets);
    });

    testWidgets('compact (500 dp) : AUCUNE exception, AUCUN `ListTile`', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, nav: _nav(itemBuilder: modeAware));

      // C'est exactement l'échec mesuré chez IFFD :
      // `BoxConstraints forces an infinite width`.
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>(_kTileKey)), findsNothing);
    });

    testWidgets(
      'CONTRE-PREUVE : un `ListTile` INCONDITIONNEL casse encore en compact',
      (tester) async {
        await setScreen(tester, 500, 800);
        await pumpDetail(
          tester,
          nav: _nav(
            // Builder qui IGNORE le mode — la faute d'IFFD, reproduite.
            itemBuilder: (context, ref, selected) =>
                ListTile(title: Text(ref.label)),
            // CR-IFFD-40 — c'est la rangée de puces qui ne borne PAS la
            // largeur : la contre-preuve n'a de sens que sur CETTE surface.
            narrowMode: ZSubfolderNarrowMode.compact,
          ),
        );

        // Le mode n'est donc PAS une commodité cosmétique : sans lui, le rendu
        // compact lève réellement. Si cette attente devenait `isNull`, c'est que
        // le sélecteur compact bornerait la largeur — et les deux tests
        // « ListTile » ci-dessus ne prouveraient plus rien.
        expect(tester.takeException(), isNotNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // CR-IFFD-30 — slot d'en-tête, masqué au repli
  // ---------------------------------------------------------------------------
  group('CR-IFFD-30 — slot `sidebarHeader`', () {
    final headerFinder = find.byKey(const ValueKey<String>(_kHeaderKey));
    const header = Text('SUBFOLDERS_TITLE', key: ValueKey<String>(_kHeaderKey));

    testWidgets('DÉFAUT (`null`) ⇒ slot absent, rendu inchangé', (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester, nav: _nav());
      expect(headerFinder, findsNothing);
    });

    testWidgets('déployée ⇒ en-tête rendu', (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester, nav: _nav(sidebarHeader: header));
      expect(find.byType(ZSubfolderSidebar), findsOneWidget);
      expect(headerFinder, findsOneWidget);
    });

    testWidgets('REPLIÉE ⇒ en-tête masqué AUTOMATIQUEMENT ; re-tap le restaure',
        (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester, nav: _nav(sidebarHeader: header));
      expect(headerFinder, findsOneWidget);

      await tester.tap(find.byKey(ZSubfolderSidebar.collapseToggleKey));
      await tester.pumpAndSettle();

      // GARDE MORDANTE : rendre l'en-tête hors du chemin `_buildExpanded` (ou
      // dans `_buildCollapsed`) le laisserait visible à 56 dp — l'hôte devrait
      // alors s'abonner lui-même à `collapsed`, ce que la CR reproche.
      expect(headerFinder, findsNothing);

      await tester.tap(find.byKey(ZSubfolderSidebar.collapseToggleKey));
      await tester.pumpAndSettle();
      expect(headerFinder, findsOneWidget);
    });

    testWidgets('le sélecteur compact NE rend PAS l\'en-tête de sidebar', (
      tester,
    ) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        nav: _nav(
          sidebarHeader: header,
          narrowMode: ZSubfolderNarrowMode.compact,
        ),
      );
      expect(find.byType(ZSubfolderCompactSelector), findsOneWidget);
      expect(headerFinder, findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // CR-LEX-81 — `width` documentée, et NON appliquée
  // ---------------------------------------------------------------------------
  group('CR-LEX-81 — `width` n\'est PAS une contrainte de layout', () {
    testWidgets('la sidebar occupe la largeur du PARENT, pas `width`', (
      tester,
    ) async {
      final selected = ValueNotifier<String?>(null);
      addTearDown(selected.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: AlignmentDirectional.topStart,
              // Contraintes LÂCHES (`maxWidth`, pas une largeur serrée) : sous
              // des contraintes serrées, un `SizedBox` interne serait de toute
              // façon écrasé par le parent — la garde ne mordrait pas.
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 600,
                ),
                child: ZSubfolderSidebar(
                  spec: _nav(),
                  collapsed: false,
                  // …et `width` vaut 200. Si la sidebar appliquait `width`, la
                  // taille rendue serait 200.
                  width: 200,
                  minWidth: 100,
                  maxWidth: 900,
                  selected: selected,
                  onSelect: (_) {},
                  onToggleCollapsed: () {},
                  onWidthChanged: (_) {},
                  onWidthChangeEnd: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Le parent OFFRE 500 dp ; `width` vaut 200. Une sidebar qui applique
      // `width` mesurerait 200.
      expect(tester.getSize(find.byType(ZSubfolderSidebar)).width, 500);
    });

    group('garde STRUCTURELLE (doc et code ne peuvent plus diverger)', () {
      const String path = 'lib/src/presentation/z_subfolder_sidebar.dart';

      List<String> codeLines() {
        final file = File(path);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'introuvable: $path (cwd=${Directory.current.path}) — lancer '
              '`flutter test` DEPUIS le package',
        );
        return file
            .readAsLinesSync()
            .where((l) {
              final t = l.trimLeft();
              return !t.startsWith('//') && !t.startsWith('///');
            })
            .toList();
      }

      /// Corps de `_buildExpanded` (lignes de code, hors commentaires).
      List<String> expandedBody(List<String> lines) {
        final start = lines.indexWhere(
          (l) => l.contains('Widget _buildExpanded('),
        );
        expect(start, isNot(-1), reason: '`_buildExpanded` introuvable');
        var end = lines.length;
        for (var i = start + 1; i < lines.length; i++) {
          if (RegExp(r'^  (Widget|void|static) ').hasMatch(lines[i])) {
            end = i;
            break;
          }
        }
        return lines.sublist(start, end);
      }

      test('`_buildExpanded` ne mentionne JAMAIS `width`', () {
        final body = expandedBody(codeLines());
        final violations = body
            .where((l) => RegExp(r'\bwidth\b').hasMatch(l))
            .map((l) => '« ${l.trim()} »')
            .toList();

        expect(
          violations,
          isEmpty,
          reason:
              '🔴 CR-LEX-81 : `width` pilote un layout dans `_buildExpanded` :\n'
              '${violations.join('\n')}\n'
              'La dartdoc de `ZSubfolderSidebar.width` PROMET l\'inverse (« aucune '
              'contrainte de layout ; à l\'hôte de poser le SizedBox »). '
              'Appliquer la contrainte ferait décider la taille au widget '
              '(contraire à AD-2) et transformerait le `SizedBox` des hôtes qui '
              'ont contourné en DOUBLON (motif CR-LEX-76). Corriger le code, ou '
              'corriger la doc ET ce test ENSEMBLE.',
        );
      });

      test('`width` n\'alimente QUE la poignée de resize (1 seul `width: width`)',
          () {
        final lines = codeLines();
        final sites = <String>[
          for (final l in lines)
            if (RegExp(r'width:\s*width\b').hasMatch(l)) l.trim(),
        ];
        // L'unique site légitime est l'argument de `_ResizeHandle`.
        expect(sites, <String>['width: width,'],
            reason: '🔴 CR-LEX-81 : `width` est passée ailleurs qu\'à la '
                'poignée de redimensionnement : $sites');
      });

      test('CONTRE-PREUVE : les scanners ATTRAPENT les régressions injectées',
          () {
        // Un `SizedBox(width: width, …)` glissé dans `_buildExpanded`…
        expect(
          RegExp(r'\bwidth\b').hasMatch('      return SizedBox(width: width,'),
          isTrue,
        );
        // …et un `ConstrainedBox` de layout piloté par `width`.
        expect(
          RegExp(r'\bwidth\b').hasMatch(
            '        constraints: BoxConstraints.tightFor(width: width),',
          ),
          isTrue,
        );
        // …mais pas une ligne neutre du corps actuel.
        expect(
          RegExp(r'\bwidth\b').hasMatch('        _resizeHandle(context, theme),'),
          isFalse,
        );
        expect(
          RegExp(r'width:\s*width\b').hasMatch('        width: widget.width,'),
          isFalse,
        );
      });

      test('la dartdoc de `width` PORTE le contrat et son symptôme', () {
        final doc = File(path).readAsStringSync();
        // Le contrat…
        expect(doc, contains('n\'applique AUCUNE contrainte de layout'));
        // …et le symptôme reconnaissable par le prochain hôte (CR-LEX-81).
        expect(doc, contains('hasSize'));
        expect(doc, contains('SizedBox('));
      });
    });
  });
}
