/// **CR-IFFD-68** — le pied de carte de dossier peut s'EMPILER sous les
/// compteurs, et c'est désormais le défaut de `ZDefaultFolderCard`.
///
/// 🔴 **Ces gardes mesurent la GÉOMÉTRIE, jamais la présence.** « le pied
/// existe dans l'arbre » ne prouve rien : il y existait déjà, à côté des
/// compteurs. Le symptôme rapporté est **« deux badges au lieu de quatre »** —
/// les gardes comptent donc les badges ENTIÈREMENT VISIBLES dans la fenêtre de
/// défilement, mesurent la LARGEUR RENDUE du créneau compteur (celle qui
/// passait de pleine à moitié) et comparent le `dy` du pied à celui des
/// compteurs.
///
/// Couverture :
/// * ① le symptôme, à la largeur des captures de l'hôte (320 dp) ;
/// * ② l'hôte **passif de la primitive** `ZFolderCard` ne bouge pas d'un pixel ;
/// * ③ réglable par **paramètre** ET par **jeton**, priorité paramètre > jeton ;
/// * ④ le régime **adaptatif** bascule bien sur son seuil, réglable des deux
///   façons ;
/// * ⑤ le badge « Archivé » — le point que la CR ne pouvait pas mesurer ;
/// * ⑥ **le plancher de contraste tient dans la NOUVELLE disposition** : c'est
///   la raison d'être de la CR (le contournement de l'hôte le lui faisait
///   perdre) ;
/// * ⑦ AD-4 : un seul créneau ⇒ AUCUNE ligne fantôme ;
/// * ⑧ échelle de texte ×1/×1.5/×2 et RTL.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

const ValueKey<String> _footerKey = ValueKey<String>('cr68-footer');

/// Le corpus de badges d'un dossier d'étude — quatre compteurs, le cas nominal
/// de la CR. Libellés COURTS à dessein : à 320 dp, ils tiennent tous les quatre
/// dans la largeur ENTIÈRE (296 dp) et **pas** dans la moitié (146 dp). C'est
/// ce qui rend la garde discriminante — un corpus qui déborderait dans les deux
/// dispositions ne mesurerait plus rien.
const List<ZFolderCardCount> _quatre = <ZFolderCardCount>[
  ZFolderCardCount(icon: Icons.style_outlined, label: '12'),
  ZFolderCardCount(icon: Icons.note_alt_outlined, label: '34'),
  ZFolderCardCount(icon: Icons.description_outlined, label: '56'),
  ZFolderCardCount(icon: Icons.folder_outlined, label: '78'),
];

const Color _kHardYellow = Color(0xFFFFFF00);

ZColorPair _resolve(ColorScheme scheme, String key) =>
    const ZColorPair(color: _kHardYellow, onColor: Color(0xFF000000));

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  double width = 320,
  double? height,
  TextDirection dir = TextDirection.ltr,
  double textScale = 1,
  ZcrudTheme? tokens,
}) async {
  tester.view.physicalSize = const Size(2000, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final Widget framed = height == null
      ? SingleChildScrollView(child: SizedBox(width: width, child: card))
      : SizedBox(width: width, height: height, child: card);
  final ThemeData base = ThemeData.light(useMaterial3: true);
  // 🔴 Les jetons sont posés par un `Theme` IMBRIQUÉ, jamais par
  // `MaterialApp.theme` : ce dernier passe par un `AnimatedTheme`, si bien
  // qu'un second `pumpWidget` mesuré sans `pumpAndSettle` rendrait encore le
  // thème PRÉCÉDENT (le `lerp` des jetons discrets bascule à t = 0.5). Deux
  // gardes de jeton se sont ainsi mesurées l'une l'autre avant correction.
  final Widget scoped = ZcrudScope(
    colorKeyResolver: _resolve,
    child: Directionality(
      textDirection: dir,
      child: Scaffold(body: Center(child: framed)),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: base,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: tokens == null
            ? scoped
            : Builder(
                builder: (BuildContext context) => Theme(
                  data: Theme.of(context).copyWith(
                    extensions: <ThemeExtension<Object?>>[
                      ...Theme.of(context).extensions.values
                          .where((ThemeExtension<dynamic> e) => e is! ZcrudTheme)
                          .cast<ThemeExtension<Object?>>(),
                      tokens,
                    ],
                  ),
                  child: scoped,
                ),
              ),
      ),
    ),
  );
}

Widget _footer([String label = 'Par toi']) => Text(
  label,
  key: _footerKey,
  maxLines: 1,
  style: const TextStyle(fontSize: 10),
);

/// La fenêtre de défilement des compteurs — c'est SA largeur qui passait de
/// pleine à moitié.
Rect _countsViewport(WidgetTester tester) =>
    tester.getRect(find.byKey(ZDefaultFolderCard.countsKey));

/// La PROPRIÉTÉ mesurée : le pied commence-t-il APRÈS la fin des compteurs ?
///
/// 🔴 Ce n'est pas une égalité de `dy` : côte à côte, la `Row` CENTRE ses
/// enfants, si bien qu'un pied de 10 dp et une rangée de badges de 20 dp n'ont
/// jamais le même `top`. Le critère mordant est le CHEVAUCHEMENT vertical —
/// c'est exactement ce qui distingue « sur la même ligne » de « dessous ».
bool _empile(WidgetTester tester) =>
    tester.getRect(find.byKey(_footerKey)).top >=
    _countsViewport(tester).bottom - 0.01;

/// Nombre de badges **entièrement** visibles : le symptôme mesuré par l'hôte
/// est « deux badges au lieu de quatre », pas « les badges existent ».
int _badgesVisibles(WidgetTester tester) {
  final Rect vue = _countsViewport(tester);
  final Finder badges = find.descendant(
    of: find.byKey(ZDefaultFolderCard.countsKey),
    matching: find.byType(Container),
  );
  int n = 0;
  for (int i = 0; i < tester.widgetList(badges).length; i++) {
    final Rect r = tester.getRect(badges.at(i));
    if (r.left >= vue.left - 0.01 && r.right <= vue.right + 0.01) n++;
  }
  return n;
}

void main() {
  group('🔴 CR-IFFD-68 ① — le symptôme MESURÉ : deux badges au lieu de quatre', () {
    testWidgets(
      'défaut de `ZDefaultFolderCard` : pied SOUS les compteurs, largeur '
      'ENTIÈRE, 4 badges sur 4',
      (WidgetTester tester) async {
        await _pump(
          tester,
          ZDefaultFolderCard(
            title: 'Valeur en douanes',
            counts: _quatre,
            footer: _footer(),
          ),
        );

        final Rect vue = _countsViewport(tester);
        final Rect pied = tester.getRect(find.byKey(_footerKey));

        // Le `dy` — la propriété qui DÉFINIT l'empilement.
        expect(
          pied.top,
          greaterThanOrEqualTo(vue.bottom),
          reason:
              '🔴 le pied est encore sur la LIGNE des compteurs (pied.dy '
              '${pied.top} < compteurs.bas ${vue.bottom}).',
        );
        // La largeur RENDUE — celle qui passait de pleine à moitié. Carte de
        // 320 dp, padding de référence 12 de chaque côté ⇒ 296.
        expect(
          vue.width,
          320 - 2 * 12,
          reason:
              '🔴 le créneau compteur ne reçoit pas la largeur ENTIÈRE : '
              '${vue.width} au lieu de 296.',
        );
        // Le symptôme exact rapporté par l'hôte.
        expect(
          _badgesVisibles(tester),
          4,
          reason: '🔴 quatre compteurs passés, moins de quatre rendus visibles.',
        );
      },
    );

    testWidgets(
      'CONTRE-MESURE : la MÊME carte en côte à côte n\'en montre que DEUX',
      (WidgetTester tester) async {
        // Sans cette contre-mesure, la garde ci-dessus serait verte pour une
        // raison quelconque (badges trop étroits, carte trop large…). Elle
        // établit que le corpus DISCRIMINE bien les deux dispositions.
        await _pump(
          tester,
          ZDefaultFolderCard(
            title: 'Valeur en douanes',
            counts: _quatre,
            footer: _footer(),
            footerPlacement: ZFolderCardFooterPlacement.beside,
          ),
        );
        expect(_countsViewport(tester).width, lessThan(160));
        expect(_badgesVisibles(tester), 2);
        expect(
          _empile(tester),
          isFalse,
          reason: '🔴 côte à côte, le pied partage la ligne des compteurs.',
        );
      },
    );

    testWidgets('le coût VERTICAL de l\'empilement est borné à `gapS` + 1 ligne',
        (WidgetTester tester) async {
      // Mesuré : +18 dp à ×1 (gapS = 4, ligne de pied = 14). Une régression qui
      // ferait exploser la hauteur (double pile, gap doublé) rougirait ici.
      await _pump(
        tester,
        ZDefaultFolderCard(
          title: 'Valeur en douanes',
          counts: _quatre,
          footer: _footer(),
          footerPlacement: ZFolderCardFooterPlacement.beside,
        ),
      );
      final double cote = tester.getSize(find.byType(ZFolderCard)).height;
      await _pump(
        tester,
        ZDefaultFolderCard(
          title: 'Valeur en douanes',
          counts: _quatre,
          footer: _footer(),
          footerPlacement: ZFolderCardFooterPlacement.below,
        ),
      );
      final double pile = tester.getSize(find.byType(ZFolderCard)).height;
      expect(pile - cote, 18);
    });
  });

  group('🔴 CR-IFFD-68 ② — la PRIMITIVE ne bouge pas d\'un pixel', () {
    testWidgets(
      'hôte passif de `ZFolderCard` : compteur, pied et badge sur la MÊME '
      'ligne, compteur et pied à largeur ÉGALE',
      (WidgetTester tester) async {
        await _pump(
          tester,
          ZFolderCard(
            title: 'Dossier',
            colorKey: 'secondary',
            counts: const SizedBox(key: ValueKey<String>('c'), height: 12),
            footer: const SizedBox(key: ValueKey<String>('f'), height: 12),
            isArchived: true,
            archivedLabel: 'Archivé',
          ),
        );
        final Rect c = tester.getRect(find.byKey(const ValueKey<String>('c')));
        final Rect f = tester.getRect(find.byKey(const ValueKey<String>('f')));
        final Rect a = tester.getRect(find.text('Archivé'));
        expect(
          f.top,
          c.top,
          reason:
              '🔴 la PRIMITIVE a changé de défaut : le pied est passé sous le '
              'compteur alors qu\'aucun réglage ne l\'a demandé.',
        );
        expect(a.top, inInclusiveRange(c.top - 4, c.top + 12));
        expect(
          f.width,
          c.width,
          reason: '🔴 les deux `Expanded` historiques ne se partagent plus la '
              'ligne à égalité.',
        );
        expect(f.width, lessThan(320 / 2));
      },
    );

    testWidgets('sans jeton ni paramètre, la primitive rend `beside`', (
      WidgetTester tester,
    ) async {
      // Deux montages, un défaut IMPLICITE et un `beside` EXPLICITE : ils
      // doivent rendre le même rect. Une bascule silencieuse du défaut de la
      // primitive rougirait ici.
      Rect rectFor(ZFolderCardFooterPlacement? p) => tester.getRect(
        find.byKey(const ValueKey<String>('f')),
      );
      await _pump(
        tester,
        const ZFolderCard(
          title: 'Dossier',
          colorKey: 'secondary',
          counts: SizedBox(key: ValueKey<String>('c'), height: 12),
          footer: SizedBox(key: ValueKey<String>('f'), height: 12),
        ),
      );
      final Rect implicite = rectFor(null);
      await _pump(
        tester,
        const ZFolderCard(
          title: 'Dossier',
          colorKey: 'secondary',
          counts: SizedBox(key: ValueKey<String>('c'), height: 12),
          footer: SizedBox(key: ValueKey<String>('f'), height: 12),
          footerPlacement: ZFolderCardFooterPlacement.beside,
        ),
      );
      expect(rectFor(ZFolderCardFooterPlacement.beside), implicite);
    });
  });

  group('🔴 CR-IFFD-68 ③ — réglable par PARAMÈTRE et par JETON', () {
    testWidgets('paramètre : la carte par défaut restitue le côte à côte', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        ZDefaultFolderCard(
          title: 'Dossier',
          counts: _quatre,
          footer: _footer(),
          footerPlacement: ZFolderCardFooterPlacement.beside,
        ),
      );
      expect(_empile(tester), isFalse);
    });

    testWidgets('paramètre : la PRIMITIVE sait empiler', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const ZFolderCard(
          title: 'Dossier',
          colorKey: 'secondary',
          counts: SizedBox(key: ValueKey<String>('c'), height: 12),
          footer: SizedBox(key: ValueKey<String>('f'), height: 12),
          footerPlacement: ZFolderCardFooterPlacement.below,
        ),
      );
      final Rect c = tester.getRect(find.byKey(const ValueKey<String>('c')));
      final Rect f = tester.getRect(find.byKey(const ValueKey<String>('f')));
      expect(f.top, greaterThanOrEqualTo(c.bottom));
      expect(c.width, 320 - 2 * 8, reason: '🔴 padding `gapM` de la primitive');
      expect(f.width, c.width);
    });

    testWidgets('jeton : `folderCardFooterPlacement` gouverne les DEUX cartes', (
      WidgetTester tester,
    ) async {
      const ZcrudTheme tokens = ZcrudTheme(
        folderCardFooterPlacement: ZFolderCardFooterPlacement.below,
      );
      await _pump(
        tester,
        const ZFolderCard(
          title: 'Dossier',
          colorKey: 'secondary',
          counts: SizedBox(key: ValueKey<String>('c'), height: 12),
          footer: SizedBox(key: ValueKey<String>('f'), height: 12),
        ),
        tokens: tokens,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey<String>('f'))).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(const ValueKey<String>('c'))).bottom,
        ),
        reason: '🔴 le jeton n\'est lu par AUCUN widget — un jeton qui ment.',
      );

      await _pump(
        tester,
        ZDefaultFolderCard(
          title: 'Dossier',
          counts: _quatre,
          footer: _footer(),
        ),
        tokens: const ZcrudTheme(
          folderCardFooterPlacement: ZFolderCardFooterPlacement.beside,
        ),
      );
      expect(
        _empile(tester),
        isFalse,
        reason: '🔴 le jeton ne ramène pas la carte par défaut au côte à côte.',
      );
    });

    testWidgets(
      '🔴 PRIORITÉ : le paramètre BAT le jeton (dans les deux sens)',
      (WidgetTester tester) async {
        // Une garde de priorité qui ne teste qu'un sens est verte même si le
        // paramètre est ignoré et que seul le jeton compte.
        await _pump(
          tester,
          ZDefaultFolderCard(
            title: 'Dossier',
            counts: _quatre,
            footer: _footer(),
            footerPlacement: ZFolderCardFooterPlacement.below,
          ),
          tokens: const ZcrudTheme(
            folderCardFooterPlacement: ZFolderCardFooterPlacement.beside,
          ),
        );
        expect(
          _empile(tester),
          isTrue,
          reason: '🔴 le jeton a battu le paramètre (sens below sur beside).',
        );

        await _pump(
          tester,
          ZDefaultFolderCard(
            title: 'Dossier',
            counts: _quatre,
            footer: _footer(),
            footerPlacement: ZFolderCardFooterPlacement.beside,
          ),
          tokens: const ZcrudTheme(
            folderCardFooterPlacement: ZFolderCardFooterPlacement.below,
          ),
        );
        expect(
          _empile(tester),
          isFalse,
          reason: '🔴 le jeton a battu le paramètre (sens beside sur below).',
        );
      },
    );
  });

  group('🔴 CR-IFFD-68 ④ — le régime ADAPTATIF bascule sur son seuil', () {
    testWidgets('sous le seuil : empilé ; au-dessus : côte à côte', (
      WidgetTester tester,
    ) async {
      // Seuil de 200 sur la largeur du BAS DE CARTE (padding déjà retranché) :
      // carte de 320 ⇒ 296 (≥ 200, côte à côte) ; carte de 200 ⇒ 176 (< 200,
      // empilé).
      Widget card() => ZDefaultFolderCard(
        title: 'Dossier',
        counts: _quatre,
        footer: _footer(),
        footerPlacement: ZFolderCardFooterPlacement.adaptive,
        footerBesideMinWidth: 200,
      );
      await _pump(tester, card(), width: 320);
      expect(
        _empile(tester),
        isFalse,
        reason: '🔴 au-dessus du seuil, le côte à côte doit revenir.',
      );
      await _pump(tester, card(), width: 200);
      expect(
        _empile(tester),
        isTrue,
        reason: '🔴 sous le seuil, la pile doit s\'appliquer.',
      );
    });

    testWidgets('le SEUIL est réglable par jeton, et le paramètre le bat', (
      WidgetTester tester,
    ) async {
      Widget card({double? param}) => ZDefaultFolderCard(
        title: 'Dossier',
        counts: _quatre,
        footer: _footer(),
        footerPlacement: ZFolderCardFooterPlacement.adaptive,
        footerBesideMinWidth: param,
      );
      // Jeton bas ⇒ côte à côte à 320.
      await _pump(
        tester,
        card(),
        tokens: const ZcrudTheme(folderCardFooterBesideMinWidth: 200),
      );
      expect(_empile(tester), isFalse);
      // Même jeton, paramètre HAUT ⇒ le paramètre gagne, la pile revient.

      await _pump(
        tester,
        card(param: 900),
        tokens: const ZcrudTheme(folderCardFooterBesideMinWidth: 200),
      );
      expect(
        _empile(tester),
        isTrue,
        reason: '🔴 le seuil du jeton a battu celui du paramètre.',
      );
    });

    testWidgets('sans réglage, le seuil de référence vaut 740 et ne bascule '
        'PAS aux largeurs de grille', (WidgetTester tester) async {
      // La valeur de référence est mesurée (2 × rangée + gapS pour le corpus
      // réel) : à 600 dp, le côte à côte ampute encore. Une baisse silencieuse
      // du seuil rougirait ici.
      expect(kZFolderCardFooterBesideMinWidth, 740);
      expect(
        ZFolderCardReference.footerBesideMinWidth,
        kZFolderCardFooterBesideMinWidth,
      );
      await _pump(
        tester,
        ZDefaultFolderCard(
          title: 'Dossier',
          counts: _quatre,
          footer: _footer(),
          footerPlacement: ZFolderCardFooterPlacement.adaptive,
        ),
        width: 600,
      );
      expect(_empile(tester), isTrue);
    });
  });

  group('🔴 CR-IFFD-68 ⑤ — le badge « Archivé » (que la CR ne pouvait mesurer)',
      () {
    testWidgets(
      'empilé AVEC pied : le badge suit la ligne du PIED, jamais celle des '
      'compteurs — qui gardent la largeur ENTIÈRE',
      (WidgetTester tester) async {
        await _pump(
          tester,
          ZDefaultFolderCard(
            title: 'Dossier',
            counts: _quatre,
            footer: _footer(),
            isArchived: true,
            archivedLabel: 'Archivé',
          ),
        );
        final Rect vue = _countsViewport(tester);
        final Rect pied = tester.getRect(find.byKey(_footerKey));
        final Rect badge = tester.getRect(find.text('Archivé'));

        expect(
          badge.top,
          greaterThanOrEqualTo(vue.bottom),
          reason:
              '🔴 le badge « Archivé » est resté sur la ligne des compteurs : '
              'il y ampute la rangée, exactement comme le pied le faisait.',
        );
        expect(badge.center.dy, closeTo(pied.center.dy, 8));
        expect(
          vue.width,
          320 - 2 * 12,
          reason:
              '🔴 les compteurs ont perdu de la largeur au profit du badge.',
        );
        expect(_badgesVisibles(tester), 4);
        // Le badge reste en FIN de ligne (RTL-safe : c'est la `Row` qui décide).
        expect(badge.right, greaterThan(pied.right));
      },
    );

    testWidgets(
      'empilé SANS pied : rien à empiler ⇒ ligne HISTORIQUE, badge compris',
      (WidgetTester tester) async {
        await _pump(
          tester,
          const ZDefaultFolderCard(
            title: 'Dossier',
            counts: _quatre,
            isArchived: true,
            archivedLabel: 'Archivé',
          ),
        );
        final Rect vue = _countsViewport(tester);
        final Rect badge = tester.getRect(find.text('Archivé'));
        expect(
          badge.center.dy,
          closeTo(vue.center.dy, 8),
          reason:
              '🔴 une ligne fantôme a été créée pour un pied ABSENT (AD-4).',
        );
        expect(vue.width, lessThan(320 - 2 * 12));
      },
    );

    testWidgets(
      '♿ le libellé « Archivé » n\'est annoncé QU\'UNE fois, empilé compris',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await _pump(
          tester,
          ZDefaultFolderCard(
            title: 'Dossier',
            counts: _quatre,
            footer: _footer(),
            isArchived: true,
            archivedLabel: 'Archivé',
            onTap: () {},
          ),
        );
        // Le texte du badge est porté par le `label` du nœud de carte ; le
        // badge lui-même reste `ExcludeSemantics`. Deux nœuds portant
        // « Archivé » = double annonce au lecteur d'écran.
        int n = 0;
        void walk(SemanticsNode node) {
          if (node.label.contains('Archivé')) n++;
          node.visitChildren((SemanticsNode c) {
            walk(c);
            return true;
          });
        }

        walk(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
        expect(
          n,
          1,
          reason:
              '🔴 « Archivé » est annoncé $n fois — l\'`ExcludeSemantics` du '
              'badge a été perdu en changeant de disposition.',
        );
        handle.dispose();
      },
    );
  });

  group('🔴 CR-IFFD-68 ⑥ — le PLANCHER DE CONTRASTE tient dans la pile', () {
    testWidgets(
      'badges toujours PEINTS PAR LA CARTE, au plancher AA, une fois empilés',
      (WidgetTester tester) async {
        // C'est la raison d'être de la CR : le contournement de l'hôte
        // (`countsSlot` recomposé) lui rendait le rendu des badges, donc lui
        // faisait perdre ce plancher. La couleur d'entrée ÉCHOUE sans
        // correction (#FFFF00 → 2.13:1).
        await _pump(
          tester,
          ZDefaultFolderCard(
            title: 'Dossier',
            counts: _quatre,
            footer: _footer(),
            isArchived: true,
            archivedLabel: 'Archivé',
          ),
        );
        // ① la disposition est bien la pile (sinon la garde mesurerait le
        // contraste de l'ANCIENNE mise en page).
        expect(_empile(tester), isTrue);
        // ② les quatre badges sont rendus PAR LA CARTE.
        final Finder badges = find.descendant(
          of: find.byKey(ZDefaultFolderCard.countsKey),
          matching: find.byType(Container),
        );
        expect(tester.widgetList(badges), hasLength(4));
        // ③ chacun est au plancher du TEXTE, mesuré contre son PROPRE fond.
        for (int i = 0; i < 4; i++) {
          final BoxDecoration deco =
              tester.widget<Container>(badges.at(i)).decoration!
                  as BoxDecoration;
          final Text label = tester.widget<Text>(
            find.descendant(of: badges.at(i), matching: find.byType(Text)),
          );
          expect(
            zContrastRatio(label.style!.color!, deco.color!),
            greaterThanOrEqualTo(ZFolderCardReference.textMinContrast),
            reason:
                '🔴 badge $i sous le plancher AA une fois le pied empilé — '
                'la garantie de CR-IFFD-64 ne survit pas au changement de '
                'disposition.',
          );
          final Icon glyph = tester.widget<Icon>(
            find.descendant(of: badges.at(i), matching: find.byType(Icon)),
          );
          expect(
            zContrastRatio(glyph.color!, deco.color!),
            greaterThanOrEqualTo(ZFolderCardReference.textMinContrast),
          );
        }
      },
    );

    testWidgets('… et le plancher est IDENTIQUE dans les deux dispositions', (
      WidgetTester tester,
    ) async {
      Color labelColor(WidgetTester t) => t
          .widget<Text>(
            find
                .descendant(
                  of: find.byKey(ZDefaultFolderCard.countsKey),
                  matching: find.byType(Text),
                )
                .first,
          )
          .style!
          .color!;
      await _pump(
        tester,
        ZDefaultFolderCard(
          title: 'Dossier',
          counts: _quatre,
          footer: _footer(),
          footerPlacement: ZFolderCardFooterPlacement.beside,
        ),
      );
      final Color cote = labelColor(tester);
      await _pump(
        tester,
        ZDefaultFolderCard(
          title: 'Dossier',
          counts: _quatre,
          footer: _footer(),
          footerPlacement: ZFolderCardFooterPlacement.below,
        ),
      );
      expect(labelColor(tester), cote);
    });
  });

  group('🔴 CR-IFFD-68 ⑦ — AD-4 : aucune ligne fantôme', () {
    testWidgets('trois créneaux absents ⇒ AUCUN bas de carte, quelle que soit '
        'la disposition', (WidgetTester tester) async {
      for (final ZFolderCardFooterPlacement p
          in ZFolderCardFooterPlacement.values) {
        await _pump(
          tester,
          ZFolderCard(
            title: 'Dossier',
            colorKey: 'secondary',
            footerPlacement: p,
          ),
        );
        final double h = tester.getSize(find.byType(ZFolderCard)).height;
        await _pump(
          tester,
          const ZFolderCard(title: 'Dossier', colorKey: 'secondary'),
        );
        expect(
          h,
          tester.getSize(find.byType(ZFolderCard)).height,
          reason: '🔴 la disposition ${p.name} réserve de la place pour un bas '
              'de carte VIDE.',
        );
      }
    });

    testWidgets(
      'un SEUL créneau ⇒ AUCUN espace sous les compteurs, dans les 3 '
      'dispositions',
      (WidgetTester tester) async {
        // 🔴 Mesure ABSOLUE, et c'est la leçon d'une garde vacante démasquée
        // pendant la campagne R3 de ce lot : comparer les trois dispositions
        // ENTRE ELLES ne détecte pas une ligne fantôme ajoutée aux TROIS à la
        // fois (elles restent égales, la garde reste verte). On mesure donc la
        // distance du bas des compteurs au bas de la carte : elle doit valoir
        // exactement le padding bas de référence, sans un dp de plus.
        final List<double> hauteurs = <double>[];
        for (final ZFolderCardFooterPlacement p
            in ZFolderCardFooterPlacement.values) {
          await _pump(
            tester,
            ZDefaultFolderCard(
              title: 'Dossier',
              counts: _quatre,
              footerPlacement: p,
            ),
          );
          hauteurs.add(tester.getSize(find.byType(ZFolderCard)).height);
          expect(
            tester.getRect(find.byType(ZFolderCard)).bottom -
                _countsViewport(tester).bottom,
            12,
            reason:
                '🔴 ${p.name} réserve de la place sous les compteurs pour un '
                'pied ABSENT (AD-4).',
          );
        }
        expect(
          hauteurs.toSet(),
          hasLength(1),
          reason:
              '🔴 sans pied, une disposition a ajouté une ligne : $hauteurs.',
        );
      },
    );
  });

  group('🔴 CR-IFFD-68 ⑧ — échelle de texte et RTL', () {
    for (final double scale in <double>[1, 1.5, 2]) {
      testWidgets('×$scale : la pile ne DÉBORDE pas en cellule bornée', (
        WidgetTester tester,
      ) async {
        await _pump(
          tester,
          ZDefaultFolderCard(
            title: 'Un titre de dossier assez long pour tenir deux lignes',
            subtitle: 'Douane',
            counts: _quatre,
            footer: _footer(),
          ),
          height: 190,
          textScale: scale,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '🔴 la pile déborde la cellule à ×$scale.',
        );
        expect(
          _empile(tester),
          isTrue,
          reason: '🔴 l\'empilement a été perdu à ×$scale.',
        );
      });
    }

    testWidgets('RTL : la pile tient, badge en FIN de ligne (donc à gauche)', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        ZDefaultFolderCard(
          title: 'Dossier',
          counts: _quatre,
          footer: _footer(),
          isArchived: true,
          archivedLabel: 'Archivé',
        ),
        dir: TextDirection.rtl,
      );
      final Rect vue = _countsViewport(tester);
      final Rect pied = tester.getRect(find.byKey(_footerKey));
      final Rect badge = tester.getRect(find.text('Archivé'));
      expect(pied.top, greaterThanOrEqualTo(vue.bottom));
      expect(vue.width, 320 - 2 * 12);
      expect(
        badge.left,
        lessThan(pied.left),
        reason: '🔴 le badge n\'a pas suivi la direction du texte (AD-13).',
      );
    });
  });
}
