/// **CR-IFFD-44** — deux capacités absentes sur la barre de fratrie.
///
/// 1. **Manque 1 — l'ajout n'était pas ADRESSABLE en emplacement.**
///    `spec.addAction != null` commandait *simultanément* le `+` de la barre et
///    le pied de la feuille : les deux seules issues étaient « les deux » ou
///    « aucun », et « aucun » retire une action réelle.
///    ⇒ [ZSubfolderAddPlacement], défaut `barAndSheet` (rendu inchangé).
/// 2. **Manque 2 — la barre n'avait aucune marge extérieure adressable.**
///    ⇒ `ZcrudTheme.subfolderBarPadding`, `null` ⇒ rendu inchangé.
///
/// 🔴 **Le piège de ce lot, nommé et évité** : une garde qui vérifie « le bouton
/// existe » serait verte dans DEUX des trois placements. Chaque valeur est donc
/// assertée **positivement ET négativement** — présent ici, **absent là** — et
/// l'action est en plus **déclenchée** depuis l'affordance survivante (le
/// placement déplace l'affordance, il ne retire pas la capacité).
///
/// 🔴 **Deuxième piège** : un plancher « ≥ 48 dp » qui mesure une contrainte
/// déclarée reste vert pendant que le rendu s'écrase. Les mesures ci-dessous
/// lisent des `RenderBox`, et le cas de rupture est **borné par le haut** : le
/// socle DÉNONCE, il ne BORNE pas — la garde prouve que la marge demandée est
/// rendue *telle quelle*, même quand elle écrase la cible.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

// ---------------------------------------------------------------------------
// Outillage
// ---------------------------------------------------------------------------

/// Libellé COURT de l'item racine.
///
/// ⚠️ Délibéré : le libellé du harnais (`ALL_SUBFOLDERS`) mesure ~196 dp dans la
/// police de test et **déborde déjà** du déclencheur sous 320 dp — un défaut
/// PRÉEXISTANT du contenu d'item, sans rapport avec la marge. Le mesurer ici
/// ferait rougir les gardes de CR-IFFD-44 pour une cause étrangère.
const String _kAll = 'ALL';

const Key _kAddIconKey = ValueKey<String>('cr44:add-icon');

/// Contenu d'item NEUTRE et de taille nulle : isole les mesures de géométrie de
/// la largeur intrinsèque du libellé.
Widget _emptyItem(BuildContext context, ZSubfolderRef ref, bool selected) =>
    const SizedBox.shrink(key: _kAddIconKey);

ZSubfolderNavSpec _spec({
  VoidCallback? addAction,
  ZSubfolderAddPlacement? addPlacement,
  ZSubfolderNarrowMode? narrowMode,
  ZSubfolderItemBuilder? itemBuilder,
}) => ZSubfolderNavSpec(
  subfolders: refs(),
  allSubfoldersLabel: _kAll,
  itemBuilder: itemBuilder,
  narrowMode: narrowMode ?? kProductionDefaultNarrowMode,
  addAction: addAction,
  addLabel: kAddLabel,
  addIcon: Icons.create_new_folder,
  addPlacement: addPlacement ?? kProductionDefaultAddPlacement,
);

Widget Function(Widget) _scoped(ZcrudTheme theme) =>
    (Widget child) => ZcrudScope(theme: theme, child: child);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
  await tester.pumpAndSettle();
}

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

Size _size(WidgetTester tester, Key key) =>
    (tester.renderObject(find.byKey(key)) as RenderBox).size;

/// Nombre de gardes de cible tactile RÉELLEMENT posées dans l'arbre.
///
/// La garde est privée : on la reconnaît par son type, ce qui est le seul moyen
/// de prouver que l'arbre est **littéralement** inchangé sans marge — « même
/// apparence » ne suffirait pas.
int _guards(WidgetTester tester) => tester
    .widgetList(
      find.byWidgetPredicate(
        (Widget w) => w.runtimeType.toString().contains('TapTargetGuard'),
      ),
    )
    .length;

/// Vide la file d'exceptions du test et rend leurs textes.
List<String> _drain(WidgetTester tester) {
  final List<String> out = <String>[];
  for (var i = 0; i < 20; i++) {
    final Object? e = tester.takeException();
    if (e == null) break;
    out.add(e.toString());
  }
  return out;
}

void main() {
  // =========================================================================
  // 1. MANQUE 1 — DÉFAUT `barAndSheet` : rendu STRICTEMENT inchangé
  // =========================================================================
  group('CR-IFFD-44 §1 — défaut `barAndSheet`', () {
    test('le défaut de PRODUCTION est `barAndSheet`', () {
      // Lu sur le socle (jamais recopié) : si le défaut basculait, aucun hôte
      // existant ne rendrait plus pareil — et cette garde le dirait.
      expect(kProductionDefaultAddPlacement, ZSubfolderAddPlacement.barAndSheet);
    });

    testWidgets('défaut : l\'ajout est offert AUX DEUX endroits', (
      tester,
    ) async {
      await setScreen(tester, 400, 800);
      await pumpDetail(tester, nav: _spec(addAction: () {}));
      expect(find.byKey(ZSubfolderSelectorBar.addKey), findsOneWidget);
      await _open(tester);
      expect(find.byKey(ZSubfolderSelectorBar.footerAddKey), findsOneWidget);
    });

    testWidgets('`addAction` nul : AUCUNE affordance, quel que soit le '
        'placement (le jeton ne FABRIQUE pas d\'action)', (tester) async {
      for (final ZSubfolderAddPlacement p in ZSubfolderAddPlacement.values) {
        await setScreen(tester, 400, 800);
        await pumpDetail(tester, nav: _spec(addPlacement: p));
        expect(
          find.byKey(ZSubfolderSelectorBar.addKey),
          findsNothing,
          reason: 'placement $p',
        );
        await _open(tester);
        expect(
          find.byKey(ZSubfolderSelectorBar.footerAddKey),
          findsNothing,
          reason: 'placement $p',
        );
        // Pas de `pageBack` : `pumpDetail` remonte une application ENTIÈRE
        // (nouveau `Navigator`) à l'itération suivante — la feuille de
        // l'itération précédente disparaît avec son arbre.
      }
    });
  });

  // =========================================================================
  // 2. MANQUE 1 — les TROIS valeurs, chacune assertée présent ICI / absent LÀ
  // =========================================================================
  group('CR-IFFD-44 §2 — les trois placements', () {
    /// Matrice de vérité EXHAUSTIVE. Une implémentation qui rendrait toujours
    /// les deux (ou toujours la barre) rougirait sur au moins deux lignes.
    const Map<ZSubfolderAddPlacement, (bool, bool)> attendu =
        <ZSubfolderAddPlacement, (bool, bool)>{
          ZSubfolderAddPlacement.barAndSheet: (true, true),
          ZSubfolderAddPlacement.sheetOnly: (false, true),
          ZSubfolderAddPlacement.barOnly: (true, false),
        };

    for (final MapEntry<ZSubfolderAddPlacement, (bool, bool)> e
        in attendu.entries) {
      final ZSubfolderAddPlacement p = e.key;
      final bool enBarre = e.value.$1;
      final bool enFeuille = e.value.$2;

      testWidgets('$p ⇒ barre=${enBarre ? "PRÉSENT" : "ABSENT"}, '
          'feuille=${enFeuille ? "PRÉSENT" : "ABSENT"}', (tester) async {
        await setScreen(tester, 400, 800);
        await pumpDetail(
          tester,
          nav: _spec(addAction: () {}, addPlacement: p),
        );
        expect(
          find.byKey(ZSubfolderSelectorBar.addKey),
          enBarre ? findsOneWidget : findsNothing,
          reason: '🔴 `+` de la BARRE sous $p',
        );
        await _open(tester);
        expect(
          find.byKey(ZSubfolderSelectorBar.footerAddKey),
          enFeuille ? findsOneWidget : findsNothing,
          reason: '🔴 pied de la FEUILLE sous $p',
        );
      });
    }

    testWidgets('`sheetOnly` : l\'action reste ATTEIGNABLE — le pied la '
        'déclenche', (tester) async {
      var appels = 0;
      await setScreen(tester, 400, 800);
      await pumpDetail(
        tester,
        nav: _spec(
          addAction: () => appels++,
          addPlacement: ZSubfolderAddPlacement.sheetOnly,
        ),
      );
      await _open(tester);
      await tester.tap(find.byKey(ZSubfolderSelectorBar.footerAddKey));
      await tester.pumpAndSettle();
      // 🔴 LA garde qui distingue « déplacer une affordance » de « retirer une
      // capacité » : le placement ne change ni l'action, ni sa cible.
      expect(appels, 1);
    });

    testWidgets('`barOnly` : l\'action reste ATTEIGNABLE — le `+` la déclenche',
        (tester) async {
      var appels = 0;
      await setScreen(tester, 400, 800);
      await pumpDetail(
        tester,
        nav: _spec(
          addAction: () => appels++,
          addPlacement: ZSubfolderAddPlacement.barOnly,
        ),
      );
      await tester.tap(find.byKey(ZSubfolderSelectorBar.addKey));
      await tester.pumpAndSettle();
      expect(appels, 1);
    });

    testWidgets('`sheetOnly` : le déclencheur RÉCUPÈRE la largeur du `+`', (
      tester,
    ) async {
      // Conséquence GÉOMÉTRIQUE, mesurée : sans elle, un socle qui se
      // contenterait de rendre le `+` transparent (au lieu de le retirer de
      // l'arbre) resterait vert sur la seule garde de clé.
      await setScreen(tester, 400, 800);
      await pumpDetail(
        tester,
        nav: _spec(addAction: () {}, itemBuilder: _emptyItem),
      );
      final double avec = _size(
        tester,
        ZSubfolderSelectorBar.triggerKey,
      ).width;

      await pumpDetail(
        tester,
        nav: _spec(
          addAction: () {},
          addPlacement: ZSubfolderAddPlacement.sheetOnly,
          itemBuilder: _emptyItem,
        ),
      );
      final double sans = _size(
        tester,
        ZSubfolderSelectorBar.triggerKey,
      ).width;

      expect(sans - avec, 48.0, reason: 'la place du `+` (48 dp) est rendue');
    });

    testWidgets('SANS EFFET sur la rangée de puces (aucune feuille à '
        'arbitrer : le `+` y reste)', (tester) async {
      // 🔴 Garde d'INDÉPENDANCE : `sheetOnly` sur une surface sans feuille
      // retirerait une action sans lui offrir de remplaçante — exactement ce
      // que ce jeton refuse de permettre.
      await setScreen(tester, 400, 800);
      await pumpDetail(
        tester,
        nav: _spec(
          addAction: () {},
          addPlacement: ZSubfolderAddPlacement.sheetOnly,
          narrowMode: ZSubfolderNarrowMode.compact,
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('suf3:compact:add')),
        findsOneWidget,
      );
    });

    testWidgets('SANS EFFET sur la sidebar (≥ 600 dp : le `+` y reste)', (
      tester,
    ) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(
        tester,
        nav: _spec(
          addAction: () {},
          addPlacement: ZSubfolderAddPlacement.sheetOnly,
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('suf3:sidebar:add')),
        findsOneWidget,
      );
    });
  });

  // =========================================================================
  // 3. MANQUE 2 — marge extérieure : `null` ⇒ arbre littéralement inchangé
  // =========================================================================
  group('CR-IFFD-44 §3 — marge `null` ⇒ rendu strictement inchangé', () {
    testWidgets('aucune enveloppe de marge, aucune garde dans l\'arbre', (
      tester,
    ) async {
      await setScreen(tester, 400, 800);
      await pumpDetail(tester, nav: _spec(addAction: () {}));
      // « Absent de l'arbre », pas « transparent » : seule forme d'inchangé
      // qu'on puisse prouver (AD-4).
      expect(find.byKey(ZSubfolderSelectorBar.barPaddingKey), findsNothing);
      expect(_guards(tester), 0);
    });

    testWidgets('la barre reste BORD À BORD dans son parent', (tester) async {
      await setScreen(tester, 400, 800);
      await pumpDetail(
        tester,
        nav: _spec(addAction: () {}, itemBuilder: _emptyItem),
      );
      final Rect bar = _rect(tester, ZSubfolderSelectorBar.barKey);
      expect(_rect(tester, ZSubfolderSelectorBar.triggerKey).left, bar.left);
      expect(_rect(tester, ZSubfolderSelectorBar.addKey).right, bar.right);
    });
  });

  // =========================================================================
  // 4. MANQUE 2 — marge posée : appliquée, et DIRECTIONNELLE
  // =========================================================================
  group('CR-IFFD-44 §4 — marge posée', () {
    const ZcrudTheme margeStart = ZcrudTheme(
      subfolderBarPadding: EdgeInsetsDirectional.only(start: 40, top: 12),
    );

    testWidgets('LTR : `start` retire 40 dp au DÉBUT, rien à la FIN', (
      tester,
    ) async {
      await setScreen(tester, 400, 800);
      await pumpDetail(
        tester,
        nav: _spec(addAction: () {}, itemBuilder: _emptyItem),
        wrap: _scoped(margeStart),
      );
      expect(find.byKey(ZSubfolderSelectorBar.barPaddingKey), findsOneWidget);
      final Rect bar = _rect(tester, ZSubfolderSelectorBar.barKey);
      expect(_rect(tester, ZSubfolderSelectorBar.triggerKey).left - bar.left, 40);
      expect(_rect(tester, ZSubfolderSelectorBar.addKey).right, bar.right);
      // L'axe vertical est servi lui aussi (une marge n'est pas qu'horizontale).
      expect(_rect(tester, ZSubfolderSelectorBar.triggerKey).top - bar.top, 12);
    });

    testWidgets('🔴 RTL : `start` bascule vers la FIN physique', (tester) async {
      await setScreen(tester, 400, 800);
      await pumpDetail(
        tester,
        nav: _spec(addAction: () {}, itemBuilder: _emptyItem),
        wrap: _scoped(margeStart),
        textDirection: TextDirection.rtl,
      );
      final Rect bar = _rect(tester, ZSubfolderSelectorBar.barKey);
      // En RTL le déclencheur est à DROITE : la marge de `start` doit se lire
      // sur le bord droit. Une implémentation qui résoudrait l'inset avec une
      // direction figée (ou qui exposerait un `EdgeInsets` physique) rendrait
      // ici 0 — c'est la mesure qui sépare AD-13 d'un `padding:` naïf.
      expect(
        bar.right - _rect(tester, ZSubfolderSelectorBar.triggerKey).right,
        40,
      );
      expect(_rect(tester, ZSubfolderSelectorBar.addKey).left, bar.left);
    });

    testWidgets('CONTRE-PREUVE : LTR et RTL ne rendent PAS la même géométrie', (
      tester,
    ) async {
      // Sans ce contrôle, une marge SYMÉTRIQUE (ou une implémentation
      // non-directionnelle) satisferait les deux gardes précédentes prises
      // isolément.
      await setScreen(tester, 400, 800);
      await pumpDetail(
        tester,
        nav: _spec(addAction: () {}, itemBuilder: _emptyItem),
        wrap: _scoped(margeStart),
      );
      final double ltr = _rect(tester, ZSubfolderSelectorBar.triggerKey).left;

      await pumpDetail(
        tester,
        nav: _spec(addAction: () {}, itemBuilder: _emptyItem),
        wrap: _scoped(margeStart),
        textDirection: TextDirection.rtl,
      );
      final double rtl = _rect(tester, ZSubfolderSelectorBar.triggerKey).left;
      expect(ltr, isNot(rtl));
    });

    testWidgets('la marge N\'A PAS d\'effet sur la FEUILLE (elle n\'habille '
        'que la barre)', (tester) async {
      await setScreen(tester, 400, 800);
      await pumpDetail(
        tester,
        nav: _spec(addAction: () {}, itemBuilder: _emptyItem),
        wrap: _scoped(margeStart),
      );
      await _open(tester);
      // La feuille SORT du sous-arbre de la barre ; y voir l'enveloppe
      // signalerait une fuite de la marge dans l'`Overlay`.
      expect(find.byKey(ZSubfolderSelectorBar.barPaddingKey), findsOneWidget);
      expect(find.byKey(ZSubfolderSelectorBar.sheetKey), findsOneWidget);
    });
  });

  // =========================================================================
  // 5. ARBITRAGE — cible tactile sous marge : DÉNONCER, jamais BORNER
  // =========================================================================
  group('CR-IFFD-44 §5 — cible tactile sous marge', () {
    /// Gouttières internes annulées : la mesure porte alors sur la marge
    /// EXTÉRIEURE seule, sans débordement parasite du contenu du déclencheur.
    ZcrudTheme _serre(double parCote) => ZcrudTheme(
      gapS: 0,
      gapM: 0,
      subfolderBarPadding: EdgeInsetsDirectional.symmetric(
        horizontal: parCote,
      ),
    );

    for (final (double largeur, double marge, double attendue)
        in <(double, double, double)>[
      // Mesures REJOUÉES (écran, marge/côté, largeur rendue du déclencheur) :
      // le `+` garde toujours ses 48 dp, c'est l'`Expanded` qui absorbe tout.
      (320, 0, 272),
      (320, 24, 224),
      (320, 48, 176),
      (400, 24, 304),
      (400, 48, 256),
    ]) {
      testWidgets('$largeur dp / marge $marge dp ⇒ déclencheur '
          '$attendue × 48 dp, AUCUNE dénonciation', (tester) async {
        await setScreen(tester, largeur, 800);
        await pumpDetail(
          tester,
          nav: _spec(addAction: () {}, itemBuilder: _emptyItem),
          wrap: _scoped(_serre(marge)),
        );
        final Size s = _size(tester, ZSubfolderSelectorBar.triggerKey);
        expect(s.width, attendue);
        // La HAUTEUR ne bouge jamais : le plancher est tenu par le
        // `ConstrainedBox` du déclencheur, sur un axe que la marge ne pince pas.
        expect(s.height, 48.0);
        expect(s.width, greaterThanOrEqualTo(48.0));
        expect(_drain(tester), isEmpty);
      });
    }

    testWidgets('🔴 marge DÉRAISONNABLE (116 dp/côté à 320 dp) : le socle rend '
        'la marge DEMANDÉE (40 dp — il ne borne pas) **et** DÉNONCE', (
      tester,
    ) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(
        tester,
        nav: _spec(addAction: () {}, itemBuilder: _emptyItem),
        wrap: _scoped(_serre(116)),
      );
      // (a) BORNE PAR LE HAUT — la mesure prouve qu'aucune correction
      //     silencieuse n'a eu lieu : 320 − 2×116 − 48 = 40 dp, sous le
      //     plancher. Un socle qui « corrigerait » rendrait 48 et cette garde
      //     rougirait : c'est l'arbitrage lui-même qui est gardé.
      expect(_size(tester, ZSubfolderSelectorBar.triggerKey).width, 40.0);
      // (b) …et le signal est ÉMIS, avec le remède nommé.
      final List<String> erreurs = _drain(tester);
      expect(
        erreurs.where((String e) => e.contains('cible tactile ÉCRASÉE')),
        isNotEmpty,
        reason: '🔴 aucune dénonciation : la rupture serait SILENCIEUSE',
      );
      expect(
        erreurs.firstWhere((String e) => e.contains('cible tactile ÉCRASÉE')),
        contains('subfolderBarPadding'),
        reason: 'le message doit NOMMER le remède',
      );
    });

    testWidgets('la garde n\'existe QUE sous marge (sans marge, arbre et '
        'silence inchangés)', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(
        tester,
        nav: _spec(addAction: () {}, itemBuilder: _emptyItem),
        wrap: _scoped(const ZcrudTheme(gapS: 0, gapM: 0)),
      );
      expect(_guards(tester), 0);
      await pumpDetail(
        tester,
        nav: _spec(addAction: () {}, itemBuilder: _emptyItem),
        wrap: _scoped(_serre(24)),
      );
      expect(_guards(tester), 1);
    });
  });
}
