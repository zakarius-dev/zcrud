/// **CR-IFFD-46** — quatre capacités absentes de la feuille de fratrie.
///
/// 1. **Le libellé de la ligne racine ne pouvait pas différer du repli du
///    déclencheur.** `allSubfoldersLabel` servait deux surfaces qui répondent à
///    deux questions différentes (« quel filtre est actif ? » / « quel
///    conteneur ? »), et `zBuildSubfolderItemContent` remettait la MÊME
///    sentinelle dans les deux cas — l'hôte ne pouvait même pas les distinguer
///    depuis son `itemBuilder`.
///    ⇒ `rootItemLabel` / `rootItemIcon` **et** [ZSubfolderSurface].
/// 2. **Le titre de la feuille n'avait pas d'alignement adressable**
///    (`TextAlign.start` en dur) ⇒ `ZcrudTheme.subfolderSheetTitleAlign`.
/// 3. **Les libellés d'item étaient bornés à une ligne** — pire : sans `…` ni
///    retour à la ligne, ils DÉBORDAIENT ⇒ `spec.itemMaxLines`.
/// 4. **La feuille était pleine largeur, sans marges adressables**
///    ⇒ `ZcrudTheme.subfolderSheetPadding`.
///
/// 🔴 **Le piège central de ce lot, nommé et évité.** « La ligne racine porte
/// bien `rootItemLabel` » est une garde qui reste VERTE si le socle rend la
/// bonne chaîne au MAUVAIS endroit (p. ex. en la posant aussi sur le
/// déclencheur, ce qui détruirait la capacité au lieu de la livrer). Chaque
/// garde de libellé mesure donc **les DEUX surfaces dans le même test**, avec
/// deux chaînes DISTINCTES, et cherche chacune dans le **sous-arbre** de sa
/// surface — jamais dans la page entière.
///
/// 🔴 **Deuxième piège** : une garde d'alignement qui lit `Text.textAlign`
/// mesure une *propriété déclarée*, pas un rendu. Les gardes du §2 lisent la
/// **géométrie peinte** (`RenderParagraph.getBoxesForSelection`) — elles
/// rougissent donc aussi si le texte cesse d'occuper toute la largeur, cas où
/// l'alignement n'aurait plus aucun effet visible.
///
/// 🔴 **Troisième piège** : une garde de repli est VACUELLE quand la valeur
/// attendue égale par hasard la valeur ambiante. Les valeurs injectées ici sont
/// toutes DÉRIVÉES et distinctes des défauts (`_kRoot` ≠ `_kAll`, marge 24 ≠ 0,
/// `maxLines` 2 ≠ 1), et la non-vacuité est assertée avant chaque mesure.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

// ---------------------------------------------------------------------------
// Outillage
// ---------------------------------------------------------------------------

/// Libellé du DÉCLENCHEUR (« quel filtre est actif ? »).
const String _kAll = 'ALL';

/// Libellé de la LIGNE RACINE (« quel conteneur ? ») — DISTINCT de [_kAll],
/// sans quoi toutes les gardes du §1 seraient vacuelles.
const String _kRoot = 'RACINE_CONTENEUR';

/// Libellé assez long pour ne PAS tenir sur une ligne à 320 dp.
const String _kLong =
    'Sous-dossier au libellé vraiment très long qui ne tient pas sur une ligne';

const IconData _kRootIcon = Icons.folder_special;

ZSubfolderNavSpec _spec({
  String? rootItemLabel,
  IconData? rootItemIcon,
  int? itemMaxLines,
  String? sheetTitle,
  ZSubfolderNarrowMode? narrowMode,
  ZSubfolderItemBuilder? itemBuilder,
  List<ZSubfolderRef>? subfolders,
}) => ZSubfolderNavSpec(
  subfolders: subfolders ?? refs(),
  allSubfoldersLabel: _kAll,
  rootItemLabel: rootItemLabel,
  rootItemIcon: rootItemIcon,
  itemMaxLines: itemMaxLines,
  sheetTitle: sheetTitle,
  itemBuilder: itemBuilder,
  narrowMode: narrowMode ?? kProductionDefaultNarrowMode,
);

Widget Function(Widget) _scoped(ZcrudTheme theme) =>
    (Widget child) => ZcrudScope(theme: theme, child: child);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
  await tester.pumpAndSettle();
}

/// Referme la feuille si elle est ouverte.
///
/// ⚠️ **Indispensable entre deux `pumpDetail` d'un même test** : la feuille est
/// une route modale ; laissée ouverte, sa barrière intercepte le tap suivant et
/// la garde mesurerait l'ANCIEN rendu — un faux vert particulièrement discret.
Future<void> _close(WidgetTester tester) async {
  if (find.byKey(ZSubfolderSelectorBar.sheetKey).evaluate().isEmpty) return;
  final NavigatorState nav = tester.state<NavigatorState>(
    find.byType(Navigator).first,
  );
  nav.pop();
  await tester.pumpAndSettle();
}

Size _size(WidgetTester tester, Key key) =>
    (tester.renderObject(find.byKey(key)) as RenderBox).size;

/// Aplatit un message d'erreur multi-lignes.
///
/// 🔴 Les messages de `FlutterError` sont **repliés à 100 colonnes** : un
/// `contains('item de la feuille')` échoue si le repli tombe au milieu de
/// l'expression. Une garde qui n'aplatirait pas serait rouge — ou verte pour
/// une raison qui n'est pas celle qu'elle croit.
String _plat(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

List<String> _drain(WidgetTester tester) {
  final List<String> out = <String>[];
  for (var i = 0; i < 30; i++) {
    final Object? e = tester.takeException();
    if (e == null) break;
    out.add(e.toString());
  }
  return out;
}

/// Exécute [corps] en CAPTURANT les erreurs Flutter à la source.
///
/// 🔴 **Mesuré : `takeException()` ne suffit pas ici.** Une dénonciation levée
/// pendant l'animation d'ouverture de la feuille est bien IMPRIMÉE mais ne
/// ressort pas de la file du testeur (le binding ne retient que la première
/// exception d'un frame, et l'ouverture modale en enchaîne plusieurs). Une
/// garde qui s'y fierait serait ROUGE alors que le socle dénonce correctement —
/// ou, pire, VERTE le jour où la dénonciation disparaîtrait pour une autre
/// raison. On installe donc notre propre collecteur.
Future<List<String>> _capture(
  WidgetTester tester,
  Future<void> Function() corps,
) async {
  final List<String> out = <String>[];
  final void Function(FlutterErrorDetails)? precedent = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails d) => out.add(d.toString());
  try {
    await corps();
  } finally {
    FlutterError.onError = precedent;
  }
  out.addAll(_drain(tester));
  return out;
}

int _guards(WidgetTester tester) => tester
    .widgetList(
      find.byWidgetPredicate(
        (Widget w) => w.runtimeType.toString().contains('TapTargetGuard'),
      ),
    )
    .length;

/// Nombre d'occurrences de [texte] DANS le sous-arbre de [racine].
///
/// 🔴 C'est l'outil qui rend les gardes du §1 mordantes : chercher dans la page
/// entière laisserait passer « la bonne chaîne au mauvais endroit ».
int _dans(WidgetTester tester, Finder racine, String texte) =>
    find.descendant(of: racine, matching: find.text(texte)).evaluate().length;

/// Abscisse GAUCHE réellement peinte du premier glyphe de [texte].
double _gauchePeinte(WidgetTester tester, String texte) {
  final RenderParagraph p = tester.renderObject<RenderParagraph>(
    find.text(texte).first,
  );
  final List<TextBox> boxes = p.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: texte.length),
  );
  expect(boxes, isNotEmpty, reason: 'aucune boîte de glyphe — mesure vacuelle');
  return boxes.first.left;
}

void main() {
  // =========================================================================
  // 1. LIBELLÉ DE LA LIGNE RACINE + SURFACE
  // =========================================================================
  group('CR-IFFD-46 §1 — la racine et le déclencheur sont enfin DISTINCTS', () {
    testWidgets('DÉFAUT (`rootItemLabel` nul) : les deux surfaces répondent '
        '`allSubfoldersLabel` — rendu strictement inchangé', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(tester, nav: _spec());
      expect(
        _dans(tester, find.byKey(ZSubfolderSelectorBar.triggerKey), _kAll),
        1,
      );
      await _open(tester);
      expect(_dans(tester, find.byKey(ZSubfolderSelectorBar.itemKey('')), _kAll),
          1);
      // …et AUCUNE trace du libellé de racine, qui n'a pas été fourni.
      expect(find.text(_kRoot), findsNothing);
    });

    testWidgets('🔴 LES DEUX SURFACES DANS LE MÊME TEST : la feuille dit '
        '`rootItemLabel`, le déclencheur dit `allSubfoldersLabel`', (
      tester,
    ) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(tester, nav: _spec(rootItemLabel: _kRoot));

      // (a) Le DÉCLENCHEUR annonce le filtre ACTIF : il ignore `rootItemLabel`.
      final Finder trigger = find.byKey(ZSubfolderSelectorBar.triggerKey);
      expect(
        _dans(tester, trigger, _kAll),
        1,
        reason: '🔴 le déclencheur a perdu `allSubfoldersLabel`',
      );
      expect(
        _dans(tester, trigger, _kRoot),
        0,
        reason: '🔴 le libellé du CONTENEUR a contaminé le DÉCLENCHEUR : la '
            'capacité est détruite, pas livrée',
      );

      // (b) La LIGNE RACINE désigne le conteneur.
      await _open(tester);
      final Finder racine = find.byKey(ZSubfolderSelectorBar.itemKey(''));
      expect(_dans(tester, racine, _kRoot), 1);
      expect(
        _dans(tester, racine, _kAll),
        0,
        reason: '🔴 la ligne racine est restée sur le repli du déclencheur',
      );
    });

    testWidgets('l\'ANNONCE a11y de la ligne racine suit le libellé RENDU', (
      tester,
    ) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(tester, nav: _spec(rootItemLabel: _kRoot));
      await _open(tester);
      // 🔴 Sans cette garde, l'œil lirait « RACINE_CONTENEUR » pendant que le
      // lecteur d'écran dirait « ALL » — pire que l'absence du réglage (AD-13).
      expect(
        find.bySemanticsLabel(_kRoot),
        findsWidgets,
        reason: '🔴 le nœud sémantique de la racine n\'a pas suivi',
      );
    });

    testWidgets('la SIDEBAR (≥ 600 dp) applique la MÊME règle', (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester, nav: _spec(rootItemLabel: _kRoot));
      expect(find.text(_kRoot), findsOneWidget);
      expect(find.text(_kAll), findsNothing);
    });

    testWidgets('la RANGÉE DE PUCES applique la MÊME règle', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(
        tester,
        nav: _spec(
          rootItemLabel: _kRoot,
          narrowMode: ZSubfolderNarrowMode.compact,
        ),
      );
      expect(find.text(_kRoot), findsOneWidget);
      expect(find.text(_kAll), findsNothing);
    });

    testWidgets('`rootItemIcon` : ABSENT de l\'arbre par défaut (AD-4)', (
      tester,
    ) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(tester, nav: _spec());
      await _open(tester);
      expect(find.byIcon(_kRootIcon), findsNothing);
    });

    testWidgets('🔴 `rootItemIcon` est posé sur la RACINE et PAS sur le '
        'déclencheur (même piège que le libellé)', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(tester, nav: _spec(rootItemIcon: _kRootIcon));
      expect(
        find
            .descendant(
              of: find.byKey(ZSubfolderSelectorBar.triggerKey),
              matching: find.byIcon(_kRootIcon),
            )
            .evaluate()
            .length,
        0,
        reason: '🔴 le glyphe de la racine a contaminé le déclencheur',
      );
      await _open(tester);
      expect(
        find
            .descendant(
              of: find.byKey(ZSubfolderSelectorBar.itemKey('')),
              matching: find.byIcon(_kRootIcon),
            )
            .evaluate()
            .length,
        1,
      );
      // …et JAMAIS sur un sous-dossier (ce n'est pas un glyphe d'item).
      expect(
        find
            .descendant(
              of: find.byKey(ZSubfolderSelectorBar.itemKey('sf0')),
              matching: find.byIcon(_kRootIcon),
            )
            .evaluate()
            .length,
        0,
      );
    });

    testWidgets('🔴 ZSubfolderSurface : le MÊME itemBuilder voit '
        '`selectorTrigger` puis `selectorSheet`', (tester) async {
      await setScreen(tester, 320, 800);
      final List<ZSubfolderSurface?> vues = <ZSubfolderSurface?>[];
      await pumpDetail(
        tester,
        nav: _spec(
          itemBuilder: (BuildContext context, ZSubfolderRef ref, bool sel) {
            vues.add(ZSubfolderSurface.maybeOf(context));
            return Text('B:${ref.label}');
          },
        ),
      );
      expect(
        vues,
        everyElement(ZSubfolderSurface.selectorTrigger),
        reason: '🔴 avant ouverture, SEUL le déclencheur est rendu',
      );
      expect(vues, isNotEmpty, reason: 'mesure vacuelle : builder jamais appelé');

      vues.clear();
      await _open(tester);
      expect(
        vues,
        contains(ZSubfolderSurface.selectorSheet),
        reason: '🔴 la feuille ne se distingue PAS du déclencheur — c\'est le '
            'défaut que CR-IFFD-46 corrige',
      );
    });

    testWidgets('ZSubfolderSurface : `sidebar`, `chips`, et `null` hors '
        'surface', (tester) async {
      await setScreen(tester, 900, 800);
      final List<ZSubfolderSurface?> vues = <ZSubfolderSurface?>[];
      ZSubfolderItemBuilder builder() =>
          (BuildContext context, ZSubfolderRef ref, bool sel) {
            vues.add(ZSubfolderSurface.maybeOf(context));
            return const SizedBox.shrink();
          };
      await pumpDetail(tester, nav: _spec(itemBuilder: builder()));
      expect(vues, isNotEmpty);
      expect(vues, everyElement(ZSubfolderSurface.sidebar));

      vues.clear();
      await setScreen(tester, 320, 800);
      await pumpDetail(
        tester,
        nav: _spec(
          narrowMode: ZSubfolderNarrowMode.compact,
          itemBuilder: builder(),
        ),
      );
      expect(vues, isNotEmpty);
      expect(vues, everyElement(ZSubfolderSurface.chips));

      // Hors de toute surface zcrud : `null`, l'hôte décide seul (AD-4).
      ZSubfolderSurface? horsSurface = ZSubfolderSurface.sidebar;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              horsSurface = ZSubfolderSurface.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(horsSurface, isNull);
    });

    testWidgets('NON CASSANT : `ZSubfolderLayoutMode` est INCHANGÉ sur les '
        'quatre surfaces', (tester) async {
      // 🔴 Le second axe ne doit RIEN changer au premier : un `switch` exhaustif
      // d'hôte sur `ZSubfolderLayoutMode` (patron que son dartdoc recommande)
      // doit continuer de compiler ET de recevoir les mêmes valeurs.
      final List<ZSubfolderLayoutMode> modes = <ZSubfolderLayoutMode>[];
      ZSubfolderItemBuilder builder() =>
          (BuildContext context, ZSubfolderRef ref, bool sel) {
            modes.add(ZSubfolderLayoutMode.of(context));
            return const SizedBox.shrink();
          };
      await setScreen(tester, 320, 800);
      await pumpDetail(tester, nav: _spec(itemBuilder: builder()));
      await _open(tester);
      expect(modes, isNotEmpty);
      expect(modes, everyElement(ZSubfolderLayoutMode.compact));
      await _close(tester);

      modes.clear();
      await setScreen(tester, 900, 800);
      await pumpDetail(tester, nav: _spec(itemBuilder: builder()));
      expect(modes, isNotEmpty);
      expect(modes, everyElement(ZSubfolderLayoutMode.sidebar));
    });

    test('`boundsWidth` : SEULE la rangée de puces n\'est pas bornée', () {
      expect(ZSubfolderSurface.chips.boundsWidth, isFalse);
      for (final ZSubfolderSurface s in ZSubfolderSurface.values) {
        if (s != ZSubfolderSurface.chips) {
          expect(s.boundsWidth, isTrue, reason: '$s devrait borner la largeur');
        }
      }
    });
  });

  // =========================================================================
  // 2. ALIGNEMENT DU TITRE DE LA FEUILLE
  // =========================================================================
  group('CR-IFFD-46 §2 — `subfolderSheetTitleAlign`', () {
    // 🔴 Titre COURT, et c'est MESURÉ : avec « TITRE_FEUILLE », le texte occupe
    // presque toute la largeur de la feuille et `center` ne déplace les glyphes
    // que de **1,0 dp** — la garde serait alors indistinguable d'un token
    // inerte. Un titre court laisse une marge de manœuvre réelle.
    const String titre = 'T';

    testWidgets('DÉFAUT (`null`) : le titre est peint au START', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(tester, nav: _spec(sheetTitle: titre));
      await _open(tester);
      final double g = _gauchePeinte(tester, titre);
      // Le `Text` occupe TOUTE la largeur (colonne `stretch`) : c'est la
      // condition sans laquelle l'alignement n'aurait aucun effet mesurable.
      final Size box = _size(tester, ZSubfolderSelectorBar.sheetTitleKey);
      expect(
        box.width,
        greaterThan(200),
        reason: '🔴 le titre ne s\'étire plus : la garde d\'alignement '
            'deviendrait VACUELLE',
      );
      expect(g, lessThan(1.0), reason: 'peint contre le bord de départ');
    });

    testWidgets('🔴 `center` DÉPLACE réellement les glyphes (géométrie '
        'peinte, pas propriété déclarée)', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(tester, nav: _spec(sheetTitle: titre));
      await _open(tester);
      final double auStart = _gauchePeinte(tester, titre);
      await _close(tester);

      await pumpDetail(
        tester,
        nav: _spec(sheetTitle: titre),
        wrap: _scoped(
          const ZcrudTheme(subfolderSheetTitleAlign: TextAlign.center),
        ),
      );
      await _open(tester);
      final double auCentre = _gauchePeinte(tester, titre);
      expect(
        auCentre,
        greaterThan(auStart + 10),
        reason: '🔴 le token est INERTE : les glyphes n\'ont pas bougé',
      );
      final Size box = _size(tester, ZSubfolderSelectorBar.sheetTitleKey);
      expect(
        (auCentre - (box.width - auCentre - _largeurPeinte(tester, titre)))
            .abs(),
        lessThan(2.0),
        reason: 'les marges gauche/droite doivent être égales',
      );
    });

    testWidgets('`end` pousse les glyphes vers la FIN', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(
        tester,
        nav: _spec(sheetTitle: titre),
        wrap: _scoped(
          const ZcrudTheme(subfolderSheetTitleAlign: TextAlign.end),
        ),
      );
      await _open(tester);
      final double g = _gauchePeinte(tester, titre);
      final Size box = _size(tester, ZSubfolderSelectorBar.sheetTitleKey);
      expect(g + _largeurPeinte(tester, titre), closeTo(box.width, 2.0));
    });

    testWidgets('🔴 RTL : `start` bascule vers la DROITE physique (AD-13)', (
      tester,
    ) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(
        tester,
        nav: _spec(sheetTitle: titre),
        textDirection: TextDirection.rtl,
      );
      await _open(tester);
      final double g = _gauchePeinte(tester, titre);
      final Size box = _size(tester, ZSubfolderSelectorBar.sheetTitleKey);
      expect(
        g + _largeurPeinte(tester, titre),
        closeTo(box.width, 2.0),
        reason: '🔴 `start` n\'a pas basculé en RTL',
      );
    });
  });

  // =========================================================================
  // 3. `itemMaxLines`
  // =========================================================================
  group('CR-IFFD-46 §3 — `itemMaxLines`', () {
    List<ZSubfolderRef> longs() => <ZSubfolderRef>[
      const ZSubfolderRef(id: 'a', label: _kLong),
    ];

    RenderParagraph para(WidgetTester tester) =>
        tester.renderObject<RenderParagraph>(find.text(_kLong).first);

    testWidgets('DÉFAUT (`null`) : arbre LITTÉRALEMENT inchangé — ni '
        '`Flexible`, ni `maxLines`, ni `overflow`', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(tester, nav: _spec(subfolders: longs()));
      await _open(tester);
      final RenderParagraph p = para(tester);
      expect(p.maxLines, isNull);
      expect(
        find
            .descendant(
              of: find.byKey(ZSubfolderSelectorBar.itemKey('a')),
              matching: find.byType(Flexible),
            )
            .evaluate(),
        isEmpty,
        reason: '🔴 un `Flexible` est apparu dans l\'arbre par défaut',
      );
      // …et le défaut DÉBORDE : c'est l'état d'aujourd'hui, mesuré, pas supposé.
      expect(
        _drain(tester).where((String e) => e.contains('overflowed')),
        isNotEmpty,
        reason: '🔴 si le défaut ne déborde plus, la neutralité a été rompue',
      );
    });

    testWidgets('🔴 `2` fait RÉELLEMENT deux lignes ET supprime le '
        'débordement', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(tester, nav: _spec(subfolders: longs(), itemMaxLines: 2));
      await _open(tester);
      final RenderParagraph p = para(tester);
      expect(p.maxLines, 2);
      expect(p.didExceedMaxLines, isTrue, reason: 'ellipsis effectivement posée');
      // La HAUTEUR peinte prouve les deux lignes — `maxLines: 2` sur un texte
      // qui resterait sur une ligne serait une garde vacuelle.
      expect(
        p.size.height,
        greaterThan(30),
        reason: '🔴 une seule ligne rendue : la borne est INERTE',
      );
      expect(
        _drain(tester).where((String e) => e.contains('overflowed')),
        isEmpty,
        reason: '🔴 le débordement subsiste',
      );
    });

    testWidgets('les CIBLES TACTILES grandissent, jamais l\'inverse (AD-13)', (
      tester,
    ) async {
      await setScreen(tester, 320, 800);
      for (final int? max in <int?>[null, 2, 3]) {
        await pumpDetail(
          tester,
          nav: _spec(subfolders: longs(), itemMaxLines: max),
        );
        await _open(tester);
        expect(
          _size(tester, ZSubfolderSelectorBar.itemKey('a')).height,
          greaterThanOrEqualTo(48.0),
          reason: '🔴 plancher de cible tactile rompu à maxLines=$max',
        );
        _drain(tester);
        await _close(tester);
        _drain(tester);
      }
    });

    testWidgets('🔴 SANS EFFET sur la rangée de puces (voie structurellement '
        'fermée) — et surtout AUCUNE exception de layout', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(
        tester,
        nav: _spec(
          subfolders: longs(),
          itemMaxLines: 2,
          narrowMode: ZSubfolderNarrowMode.compact,
        ),
      );
      // 🔴 MESURÉ, et contre-intuitif : `RenderParagraph.maxLines` vaut **1**
      // ici — mais ce n'est PAS notre borne. C'est le `DefaultTextStyle` que
      // `ChoiceChip` (Material) pose autour de son `label`. Asserter `isNull`
      // aurait fait rougir une garde pour le plancher du SDK, pas pour le
      // nôtre. Ce que le socle doit prouver, c'est qu'il n'a **rien ajouté** :
      // aucun `Flexible` (qui lèverait « incoming width constraints are
      // unbounded ») dans le sous-arbre de la rangée.
      expect(
        find
            .descendant(
              of: find.byKey(ZSubfolderCompactSelector.compactKey),
              matching: find.byType(Flexible),
            )
            .evaluate(),
        isEmpty,
        reason: '🔴 un `Flexible` a été posé là où la largeur est NON bornée',
      );
      expect(
        _drain(tester).where((String e) => e.contains('unbounded')),
        isEmpty,
        reason: '🔴 la rangée de puces a été cassée par la borne',
      );
    });

    testWidgets('la SIDEBAR : défaut 1 ligne, borne adressable', (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester, nav: _spec(subfolders: longs()));
      expect(para(tester).maxLines, 1, reason: 'défaut historique inchangé');
      await pumpDetail(tester, nav: _spec(subfolders: longs(), itemMaxLines: 3));
      expect(para(tester).maxLines, 3);
    });

    testWidgets('🔴 ARBITRAGE — bande `aboveTabBar` : 2 lignes NE COÛTENT '
        'RIEN, 3 lignes DÉNONCENT, la déclaration corrige', (tester) async {
      // (a) 2 lignes : la bande par défaut (48 dp) absorbe — mesuré, alors que
      //     l'hôte supposait l'inverse sans l'avoir mesuré.
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        nav: _spec(subfolders: longs(), itemMaxLines: 2),
        initialSelectedSubfolderId: 'a',
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
      );
      expect(
        _drain(tester).where((String e) => e.contains('overflowed')),
        isEmpty,
        reason: '🔴 2 lignes débordent : l\'arbitrage doit être rejoué',
      );
      expect(_size(tester, ZSubfolderSelectorBar.barKey).height, 48.0);

      // (b) 3 lignes sous une bande NON déclarée : le socle DÉNONCE.
      await pumpDetail(
        tester,
        nav: _spec(subfolders: longs(), itemMaxLines: 3),
        initialSelectedSubfolderId: 'a',
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
      );
      expect(
        _drain(tester).where((String e) => e.contains('overflowed')),
        isNotEmpty,
        reason: '🔴 la bande sous-déclarée serait tronquée EN SILENCE — c\'est '
            'précisément ce que le socle refuse',
      );

      // (c) …et la DÉCLARATION est le remède, pas un bornage silencieux.
      await pumpDetail(
        tester,
        nav: _spec(subfolders: longs(), itemMaxLines: 3),
        initialSelectedSubfolderId: 'a',
        subfolderNavPlacement: ZSubfolderNavPlacement.aboveTabBar,
        subfolderNavBandHeight: 68,
      );
      expect(
        _drain(tester).where((String e) => e.contains('overflowed')),
        isEmpty,
        reason: '🔴 la hauteur déclarée ne corrige plus rien',
      );
      expect(_size(tester, ZSubfolderSelectorBar.barKey).height, 68.0);
    });
  });

  // =========================================================================
  // 4. `subfolderSheetPadding`
  // =========================================================================
  group('CR-IFFD-46 §4 — `subfolderSheetPadding`', () {
    testWidgets('DÉFAUT (`null`) : AUCUNE enveloppe dans l\'arbre (AD-4)', (
      tester,
    ) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(tester, nav: _spec());
      await _open(tester);
      expect(find.byKey(ZSubfolderSelectorBar.sheetPaddingKey), findsNothing);
      expect(_guards(tester), 0, reason: 'aucune garde non plus, sans marge');
    });

    testWidgets('🔴 la marge est POSÉE, et le plafond de 80 % de hauteur '
        'd\'écran reste INTACT', (tester) async {
      await setScreen(tester, 320, 800);
      // 🔴 Assez de fratrie pour que le PLAFOND morde réellement : mesuré, avec
      // 3 sous-dossiers la feuille ne fait que 256 dp de haut et le plafond de
      // 640 dp n'est jamais atteint — la garde serait VACUELLE.
      final List<ZSubfolderRef> nombreuse = <ZSubfolderRef>[
        for (int i = 0; i < 12; i++)
          ZSubfolderRef(id: 's$i', label: 'Sous-dossier $i'),
      ];
      await pumpDetail(tester, nav: _spec(subfolders: nombreuse));
      await _open(tester);
      expect(
        tester.renderObject<RenderBox>(find.byType(BottomSheet).first).size
            .height,
        640.0,
        reason: '🔴 le plafond ne MORD pas : la garde serait vacuelle',
      );
      final Size sans = _size(tester, ZSubfolderSelectorBar.sheetKey);
      _drain(tester);
      await _close(tester);

      await pumpDetail(
        tester,
        nav: _spec(subfolders: nombreuse),
        wrap: _scoped(
          const ZcrudTheme(
            subfolderSheetPadding: EdgeInsetsDirectional.all(24),
          ),
        ),
      );
      await _open(tester);
      expect(find.byKey(ZSubfolderSelectorBar.sheetPaddingKey), findsOneWidget);
      final Size avec = _size(tester, ZSubfolderSelectorBar.sheetKey);
      expect(
        sans.width - avec.width,
        48.0,
        reason: 'la marge DEMANDÉE est rendue (24 dp par côté)',
      );
      // 🔴 Le vrai risque du point 4 : casser le plafond de v0.36.0. Il est
      // posé sur la FEUILLE, au-dessus de cette marge — mesuré.
      final RenderBox feuille = tester.renderObject<RenderBox>(
        find.byType(BottomSheet).first,
      );
      expect(
        feuille.size.height,
        640.0,
        reason: '🔴 le plafond de 80 % (0,8 × 800) a bougé',
      );
    });

    testWidgets('🔴 RTL : `start` bascule vers la FIN physique (AD-13)', (
      tester,
    ) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(
        tester,
        nav: _spec(),
        textDirection: TextDirection.rtl,
        wrap: _scoped(
          const ZcrudTheme(
            subfolderSheetPadding: EdgeInsetsDirectional.only(start: 40),
          ),
        ),
      );
      await _open(tester);
      final Rect col = tester.getRect(
        find.byKey(ZSubfolderSelectorBar.sheetKey),
      );
      final Rect feuille = tester.getRect(find.byType(BottomSheet).first);
      // En RTL, `start` = droite : c'est le bord DROIT qui recule.
      expect(
        feuille.right - col.right,
        greaterThan(40.0),
        reason: '🔴 la marge directionnelle n\'a pas basculé',
      );
      // ⚠️ Les libellés du harnais débordent horizontalement sous une largeur
      // réduite — défaut PRÉEXISTANT du contenu d'item (c'est précisément ce
      // que `itemMaxLines` répare au §3), sans rapport avec la marge. Le
      // mesurer ici ferait rougir cette garde pour une cause étrangère.
      _drain(tester);
    });

    testWidgets('🔴 marge DÉRAISONNABLE : le socle rend la marge DEMANDÉE '
        '(il ne borne pas) **et** DÉNONCE en nommant le remède', (tester) async {
      await setScreen(tester, 320, 800);
      final List<String> erreurs = await _capture(tester, () async {
        await pumpDetail(
          tester,
          nav: _spec(),
          wrap: _scoped(
            const ZcrudTheme(
              subfolderSheetPadding: EdgeInsetsDirectional.symmetric(
                horizontal: 150,
              ),
            ),
          ),
        );
        await _open(tester);
      });
      // (a) BORNE PAR LE HAUT : aucune correction silencieuse. 320 − 2×150 − 16
      //     (gouttière interne) = 4 dp, très en-dessous du plancher.
      final double l = _size(tester, ZSubfolderSelectorBar.itemKey('')).width;
      expect(
        l,
        lessThan(48.0),
        reason: '🔴 le socle a BORNÉ la marge : il rendrait autre chose que ce '
            'que l\'hôte a demandé, en silence',
      );
      // (b) …et le signal est ÉMIS, avec le remède nommé.
      final Iterable<String> denonciations = erreurs.where(
        (String e) => e.contains('cible tactile ÉCRASÉE'),
      );
      expect(
        denonciations,
        isNotEmpty,
        reason: '🔴 la rupture de cible serait SILENCIEUSE',
      );
      expect(_plat(denonciations.first), contains('subfolderSheetPadding'));
      expect(
        _plat(denonciations.first),
        contains('item de la feuille'),
        reason: 'le message doit NOMMER le sujet écrasé',
      );
    });

    testWidgets('marge RAISONNABLE : aucune dénonciation', (tester) async {
      await setScreen(tester, 320, 800);
      final List<String> erreurs = await _capture(tester, () async {
        await pumpDetail(
          tester,
          nav: _spec(),
          wrap: _scoped(
            const ZcrudTheme(
              subfolderSheetPadding: EdgeInsetsDirectional.all(24),
            ),
          ),
        );
        await _open(tester);
      });
      expect(
        erreurs.where((String e) => e.contains('cible tactile')),
        isEmpty,
      );
      expect(_guards(tester), greaterThan(0), reason: 'la garde EST posée');
    });

    testWidgets('la DÉNONCIATION de la BARRE reste distincte (non-régression '
        'CR-IFFD-44)', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(
        tester,
        nav: _spec(
          itemBuilder: (BuildContext c, ZSubfolderRef r, bool s) =>
              const SizedBox.shrink(),
        ),
        wrap: _scoped(
          const ZcrudTheme(
            gapS: 0,
            gapM: 0,
            // 140 (et non 116 comme dans CR-IFFD-44) : ce harnais-ci ne fournit
            // pas d'`addAction`, donc pas de bouton `+` de 48 dp — le
            // déclencheur récupère cette largeur et le seuil de rupture monte
            // d'autant. Recopier 116 aurait donné une garde VERTE par absence
            // de dénonciation, en croyant mesurer la dénonciation.
            subfolderBarPadding: EdgeInsetsDirectional.symmetric(
              horizontal: 140,
            ),
          ),
        ),
      );
      final List<String> erreurs = _drain(tester);
      final Iterable<String> d = erreurs.where(
        (String e) => e.contains('cible tactile ÉCRASÉE'),
      );
      expect(d, isNotEmpty);
      expect(_plat(d.first), contains('subfolderBarPadding'));
      expect(_plat(d.first), contains('déclencheur'));
    });
  });
}

/// Largeur RÉELLEMENT peinte de [texte] (somme des boîtes de glyphes).
double _largeurPeinte(WidgetTester tester, String texte) {
  final RenderParagraph p = tester.renderObject<RenderParagraph>(
    find.text(texte).first,
  );
  final List<TextBox> boxes = p.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: texte.length),
  );
  expect(boxes, isNotEmpty);
  double min = boxes.first.left;
  double max = boxes.first.right;
  for (final TextBox b in boxes) {
    if (b.left < min) min = b.left;
    if (b.right > max) max = b.right;
  }
  return max - min;
}
