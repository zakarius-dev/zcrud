/// CHAT-4b — `ZItemActionsMenu` est un CONSOMMATEUR de la couture `zcrud_menu`.
///
/// Ce que ces gardes verrouillent, dans l'ordre du risque :
///   1. **non-régression** : un appelant qui n'utilise AUCUNE capacité neuve
///      obtient le rendu d'avant (colonne, glyphe de repli, info-bulle du SDK) ;
///   2. **absorption** : le déclencheur et la surface appartiennent au
///      `ZMenuRenderer` — un renderer injecté les remplace RÉELLEMENT, preuve
///      qu'aucun `PopupMenuButton` n'est plus construit en dur ici ;
///   3. **capacités neuves ATTEIGNABLES** : `permitted`, `disabledReason`, les
///      identités partagées, et `ZMenuEntryTile` dans le slot ;
///   4. **a11y (AD-13)** : ≥ 48 dp et libellé annoncé EXACTEMENT une fois, sur
///      la surface flottante — pas sur le déclencheur ;
///   5. **RTL RÉEL** : mesuré sur la SURFACE FLOTTANTE.
///
/// 🔴 **Le piège RTL, nommément.** Un `Directionality` posé SOUS `MaterialApp`
/// (dans `home:`) ne s'applique PAS au menu : celui-ci est une route poussée
/// dans l'`Overlay` du `Navigator`, qui est un ANCÊTRE de `home`. Une garde
/// écrite ainsi mesure la direction du DÉCLENCHEUR et reste verte alors que la
/// surface est en LTR. Ces gardes posent donc la direction via
/// `MaterialApp.builder`, qui enveloppe le `Navigator` LUI-MÊME — et le
/// vérifient par une SONDE qui échouerait si le piège était encore là.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

const String kOuvrir = 'OUVRIR-XYZ';
const String kRenommer = 'RENOMMER-XYZ';
const String kSupprimer = 'SUPPRIMER-XYZ';
const String kMotif = 'MOTIF-BIENTOT-XYZ';

ZItemAction _ouvrir({VoidCallback? onSelected}) => ZItemAction(
      kind: ZItemActionKind.open,
      label: kOuvrir,
      icon: Icons.open_in_new,
      onSelected: onSelected ?? () {},
    );

/// Enveloppe NEUTRE : aucune direction forcée (le défaut LTR du harnais).
Widget _app(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ZcrudScope(child: Scaffold(body: Center(child: child))),
    );

/// Enveloppe DIRECTIONNELLE — la direction est posée AU-DESSUS du `Navigator`
/// (via `builder`), donc elle atteint l'`Overlay` où vit la surface flottante.
Widget _appDirectionnelle(Widget child, TextDirection direction) => MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, navigator) =>
          Directionality(textDirection: direction, child: navigator!),
      home: ZcrudScope(child: Scaffold(body: Center(child: child))),
    );

/// Renderer d'essai : ne rend RIEN d'un menu, seulement un marqueur — c'est ce
/// qui rend la substitution observable sans ambiguïté (patron `_SpyRenderer`
/// d'`ad57_reorder_renderer_seam_test.dart`).
class _RendererEspion extends ZMenuRenderer {
  const _RendererEspion(this.vues);

  final List<ZMenuRequest> vues;

  @override
  Widget build(BuildContext context, ZMenuRequest request) {
    vues.add(request);
    return const Text('RENDU-SUBSTITUE');
  }
}

void main() {
  group('1. NON-RÉGRESSION — l\'appelant historique voit le rendu d\'avant', () {
    testWidgets('colonne par défaut : un PopupMenuItem par action visible, '
        'libellé et glyphe INJECTÉS', (tester) async {
      await tester.pumpWidget(_app(ZItemActionsMenu(
        actions: <ZItemAction>[
          _ouvrir(),
          ZItemAction(
            kind: ZItemActionKind.rename,
            label: kRenommer,
            icon: Icons.edit,
            onSelected: () {},
          ),
          // Ni actionnable ni motivée ⇒ ABSENTE (AD-4, règle HISTORIQUE).
          const ZItemAction(
            kind: ZItemActionKind.delete,
            label: kSupprimer,
            icon: Icons.delete,
          ),
        ],
      )));
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuItem<ZMenuEntry>), findsNWidgets(2));
      expect(find.text(kOuvrir), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
      expect(find.text(kSupprimer), findsNothing,
          reason: 'AD-4 : onSelected null SANS motif ⇒ ABSENTE, jamais grisée');
    });

    testWidgets('déclencheur : glyphe de REPLI et cible ≥ 48 dp inchangés',
        (tester) async {
      await tester.pumpWidget(_app(ZItemActionsMenu(
        actions: <ZItemAction>[_ouvrir()],
      )));

      expect(find.byIcon(Icons.more_vert), findsOneWidget,
          reason: 'sans `icon:`, le repli neutre documenté est conservé');
      final taille = tester.getSize(find.byType(ZItemActionsMenu));
      expect(taille.width, greaterThanOrEqualTo(48.0));
      expect(taille.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('🔴 sans `tooltip:`, l\'info-bulle reste celle du SDK '
        '(aucune chaîne codée en dur)', (tester) async {
      await tester.pumpWidget(_app(ZItemActionsMenu(
        actions: <ZItemAction>[_ouvrir()],
      )));

      // 🔴 `ZMenuTrigger.semanticLabel` est REQUIS : la façade doit le remplir
      // avec le repli LOCALISÉ du SDK — la chaîne même que `PopupMenuButton`
      // posait auparavant. Une chaîne inventée ici serait un libellé en dur
      // (FR-26/FR-23) ET une régression d'annonce.
      final attendu = MaterialLocalizations.of(
        tester.element(find.byType(ZItemActionsMenu)),
      ).showMenuTooltip;
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byIcon(Icons.more_vert),
          matching: find.byType(Tooltip),
        ).first,
      );
      expect(tooltip.message, attendu);
    });

    testWidgets('`tooltip:` injecté ⇒ c\'est LUI qui est porté', (tester) async {
      await tester.pumpWidget(_app(ZItemActionsMenu(
        tooltip: 'MENU-XYZ',
        actions: <ZItemAction>[_ouvrir()],
      )));
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byIcon(Icons.more_vert),
          matching: find.byType(Tooltip),
        ).first,
      );
      expect(tooltip.message, 'MENU-XYZ');
    });

    testWidgets('sélection : l\'action est invoquée EXACTEMENT 1× et la '
        'surface se ferme', (tester) async {
      var ouvre = 0;
      var renomme = 0;
      await tester.pumpWidget(_app(ZItemActionsMenu(
        actions: <ZItemAction>[
          _ouvrir(onSelected: () => ouvre++),
          ZItemAction(
            kind: ZItemActionKind.rename,
            label: kRenommer,
            icon: Icons.edit,
            onSelected: () => renomme++,
          ),
        ],
      )));
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kOuvrir));
      await tester.pumpAndSettle();

      expect(ouvre, 1, reason: 'ni zéro (chemin mort) ni deux (double appel)');
      expect(renomme, 0);
      expect(find.text(kOuvrir), findsNothing, reason: 'surface refermée');
    });
  });

  group('2. ABSORPTION — le déclencheur appartient au renderer', () {
    testWidgets('🔴 un ZMenuRenderer injecté REMPLACE le PopupMenuButton',
        (tester) async {
      // Si la façade construisait encore son `PopupMenuButton` en dur, ce
      // marqueur ne pourrait PAS apparaître — c'est le pendant DYNAMIQUE du
      // grep négatif statique de `z_menu_supersedes_test.dart`.
      final vues = <ZMenuRequest>[];
      await tester.pumpWidget(_app(ZItemActionsMenu(
        renderer: _RendererEspion(vues),
        actions: <ZItemAction>[_ouvrir()],
      )));

      expect(find.text('RENDU-SUBSTITUE'), findsOneWidget);
      expect(find.byType(PopupMenuButton<ZMenuEntry>), findsNothing);
      expect(vues, hasLength(1));
      expect(vues.single.entries.single.label, kOuvrir,
          reason: 'la requête neutre porte bien l\'action traduite');
    });

    testWidgets('un ZMenuScope de l\'hôte est honoré (sans paramètre)',
        (tester) async {
      final vues = <ZMenuRequest>[];
      await tester.pumpWidget(MaterialApp(
        home: ZMenuScope(
          renderer: _RendererEspion(vues),
          child: ZcrudScope(
            child: Scaffold(
              body: ZItemActionsMenu(actions: <ZItemAction>[_ouvrir()]),
            ),
          ),
        ),
      ));

      expect(find.text('RENDU-SUBSTITUE'), findsOneWidget);
      expect(vues, hasLength(1));
    });
  });

  group('3. CAPACITÉS NEUVES atteignables depuis ZItemActionsMenu', () {
    testWidgets('🔴 `permitted: false` ⇒ action ABSENTE, même AVEC un callback',
        (tester) async {
      var appels = 0;
      await tester.pumpWidget(_app(ZItemActionsMenu(
        actions: <ZItemAction>[
          _ouvrir(),
          ZItemAction(
            kind: ZItemActionKind.delete,
            label: kSupprimer,
            icon: Icons.delete,
            permitted: false,
            // 🔴 Le DROIT est séparé de l'EFFET : l'appelant n'a plus à
            // traduire `permitted ? onSelected : null` (la couche que IFFD
            // avait dû écrire, `IffdMenuAction`/`iffdMenuActions()`).
            onSelected: () => appels++,
          ),
        ],
      )));
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();

      expect(find.text(kOuvrir), findsOneWidget, reason: 'sonde : menu ouvert');
      expect(find.text(kSupprimer), findsNothing);
      expect(appels, 0);
    });

    testWidgets('🔴 `disabledReason` ⇒ action PRÉSENTE, INERTE, motif ANNONCÉ',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(ZItemActionsMenu(
        actions: <ZItemAction>[
          _ouvrir(),
          const ZItemAction(
            kind: ZItemActionKind.rename,
            label: kRenommer,
            icon: Icons.edit,
            disabledReason: kMotif,
          ),
        ],
      )));
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();

      // PRÉSENTE (là où la règle absolue la rendait ABSENTE) …
      expect(find.text(kRenommer), findsOneWidget);
      // … et MOTIVÉE (c'est ce que lex réécrit 297 lignes pour obtenir).
      expect(find.text(kMotif), findsOneWidget);

      final donnees = tester
          .getSemantics(find
              .ancestor(
                of: find.text(kRenommer),
                matching: find.byType(PopupMenuItem<ZMenuEntry>),
              )
              .first)
          .getSemanticsData();
      // Le motif est porté par le slot `hint` — jamais concaténé au libellé
      // (aucun séparateur codé en dur à localiser, FR-23).
      expect(donnees.hint, contains(kMotif));
      expect(donnees.hasAction(SemanticsAction.tap), isFalse,
          reason: '🔴 une entrée désactivée ne doit exposer AUCUNE action de '
              'tap : un lecteur d\'écran la présenterait comme actionnable');

      // INERTE : la taper ne referme rien et n'invoque rien.
      await tester.tap(find.text(kRenommer));
      await tester.pumpAndSettle();
      expect(find.text(kRenommer), findsOneWidget,
          reason: '🔴 une entrée désactivée ne doit pas fermer la surface');
      handle.dispose();
    });

    test('les identités PARTAGÉES sont dérivées de la nature', () {
      expect(_ouvrir().entryId, ZMenuEntryIds.open);
      expect(
        const ZItemAction(
          kind: ZItemActionKind.delete,
          label: kSupprimer,
          icon: Icons.delete,
        ).entryId,
        ZMenuEntryIds.delete,
      );
      // Une action hors nomenclature porte SON identité (pendant de `custom`).
      expect(
        const ZItemAction(
          kind: ZItemActionKind.custom,
          label: 'X',
          icon: Icons.abc,
          id: ZMenuEntryIds.moveUp,
        ).entryId,
        ZMenuEntryIds.moveUp,
      );
      // `custom` sans identité déclarée : repli documenté, jamais une levée.
      expect(
        const ZItemAction(
          kind: ZItemActionKind.custom,
          label: 'X',
          icon: Icons.abc,
        ).entryId,
        'custom',
      );
    });

    test('la projection neutre porte la nature DESTRUCTIVE (donnée, pas style)',
        () {
      expect(
        const ZItemAction(
          kind: ZItemActionKind.delete,
          label: kSupprimer,
          icon: Icons.delete,
        ).toMenuEntry().isDestructive,
        isTrue,
      );
      expect(_ouvrir().toMenuEntry().isDestructive, isFalse);
    });

    testWidgets('🔴 le slot peut composer ZMenuEntryTile — le renoncement a11y '
        'du menuBuilder est LEVÉ', (tester) async {
      await tester.pumpWidget(_app(ZItemActionsMenu(
        menuBuilder: (context, actions, select) => SizedBox(
          width: 260,
          child: Wrap(
            children: <Widget>[
              for (final action in actions)
                SizedBox(
                  key: ValueKey<String>('cell-${action.label}'),
                  width: 120,
                  child: ZMenuEntryTile(
                    entry: action.toMenuEntry(),
                    direction: Axis.vertical,
                    onSelected: () => select(action),
                  ),
                ),
            ],
          ),
        ),
        actions: <ZItemAction>[
          _ouvrir(),
          ZItemAction(
            kind: ZItemActionKind.rename,
            label: kRenommer,
            icon: Icons.edit,
            onSelected: () {},
          ),
        ],
      )));
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();

      // Disposition NON-COLONNE effective (mesure par ORDONNÉES réelles).
      final y1 = tester.getTopLeft(find.byKey(const ValueKey('cell-$kOuvrir'))).dy;
      final y2 =
          tester.getTopLeft(find.byKey(const ValueKey('cell-$kRenommer'))).dy;
      expect((y1 - y2).abs(), lessThan(0.5));

      // 🔴 …ET la cellule du SOCLE tient les 48 dp que l'hôte devait assurer
      // seul avant CHAT-4b.
      expect(find.byType(ZMenuEntryTile), findsWidgets,
          reason: 'contrôle positif : sans cellule montée, les boucles '
              'ci-dessous seraient vertes à vide');
      for (final tile in tester.widgetList<ZMenuEntryTile>(
        find.byType(ZMenuEntryTile),
      )) {
        expect(tile.entry.label, isNotEmpty);
      }
      // 🔴 GARDE RETENDUE (finding F5). La version d'origine lisait la TAILLE
      // RENDUE du `ConstrainedBox` : en composition verticale (icône 24 +
      // gapS + libellé) la hauteur naturelle dépasse déjà 48 dp et la largeur
      // est fixée par le `SizedBox(width: 120)` du test — le plancher pouvait
      // donc être mis à 0 sans qu'elle rougisse. On lit désormais la CONTRAINTE
      // elle-même, PUIS la taille rendue.
      for (final label in <String>[kOuvrir, kRenommer]) {
        final boite = find
            .ancestor(
              of: find.text(label),
              matching: find.byType(ConstrainedBox),
            )
            .first;
        final contraintes = tester.widget<ConstrainedBox>(boite).constraints;
        expect(contraintes.minHeight, greaterThanOrEqualTo(48.0),
            reason: '🔴 « $label » : la cellule ne DEMANDE plus ses 48 dp '
                '(minHeight = ${contraintes.minHeight}) — sa taille rendue ici '
                'ne le dirait pas, elle vient du contenu et du SizedBox.');
        expect(contraintes.minWidth, greaterThanOrEqualTo(48.0));
        final taille = tester.getSize(boite);
        expect(taille.height, greaterThanOrEqualTo(48.0));
        expect(taille.width, greaterThanOrEqualTo(48.0));
      }
    });

    testWidgets('le slot ne reçoit NI l\'action absente NI la non-permise, et '
        '`select` invoque 1×', (tester) async {
      late List<ZItemAction> recues;
      var ouvre = 0;
      await tester.pumpWidget(_app(ZItemActionsMenu(
        menuBuilder: (context, actions, select) {
          recues = actions;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final a in actions)
                TextButton(
                  key: ValueKey<String>('btn-${a.label}'),
                  onPressed: () => select(a),
                  child: Text(a.label),
                ),
            ],
          );
        },
        actions: <ZItemAction>[
          _ouvrir(onSelected: () => ouvre++),
          const ZItemAction(
            kind: ZItemActionKind.delete,
            label: kSupprimer,
            icon: Icons.delete,
          ),
          ZItemAction(
            kind: ZItemActionKind.rename,
            label: kRenommer,
            icon: Icons.edit,
            permitted: false,
            onSelected: () {},
          ),
        ],
      )));
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();

      expect(recues.map((a) => a.label), <String>[kOuvrir]);

      await tester.tap(find.byKey(const ValueKey('btn-$kOuvrir')));
      await tester.pumpAndSettle();
      expect(ouvre, 1);
      expect(find.byKey(const ValueKey('btn-$kOuvrir')), findsNothing,
          reason: 'select() ferme la surface, par le MÊME chemin que le défaut');
    });
  });

  group('4. A11Y (AD-13) sur la SURFACE FLOTTANTE', () {
    testWidgets('🔴 chaque item ≥ 48 dp ET annoncé EXACTEMENT une fois',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(ZItemActionsMenu(
        actions: <ZItemAction>[
          _ouvrir(),
          ZItemAction(
            kind: ZItemActionKind.rename,
            label: kRenommer,
            icon: Icons.edit,
            onSelected: () {},
          ),
        ],
      )));
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();

      for (final label in <String>[kOuvrir, kRenommer]) {
        final cible = find
            .ancestor(
              of: find.text(label),
              matching: find.byType(PopupMenuItem<ZMenuEntry>),
            )
            .first;
        expect(tester.getSize(cible).height, greaterThanOrEqualTo(48.0),
            reason: '🔴 « $label » : item de menu intappable au doigt');

        // 🔴 Le label FUSIONNÉ (`getSemanticsData`), pas le label PROPRE : sur
        // une *merge boundary* ce dernier est vide, et « 0 == 0 » passerait
        // pour une garde verte.
        final annonce = tester.getSemantics(cible).getSemanticsData().label;
        final occurrences =
            RegExp(RegExp.escape(label)).allMatches(annonce).length;
        expect(occurrences, 1,
            reason: '🔴 « $label » annoncée $occurrences fois (« $annonce ») — '
                '0 ⇒ MUETTE ; 2 ⇒ RÉPÉTÉE (excludeSemantics manquant).');
      }
      handle.dispose();
    });

    testWidgets('🔴 la CELLULE DU SOCLE porte elle-même le plancher de 48 dp',
        (tester) async {
      // 🔴 GARDE RETENDUE (défaut mesuré en CHAT-4b). La mesure ci-dessus, sur
      // l'ancêtre `PopupMenuItem`, est TAUTOLOGIQUE : Material impose déjà
      // `kMinInteractiveDimension` (48) à ses items. Injecter `minHeight: 1.0`
      // dans `ZMenuEntryTile` laissait donc la garde VERTE — elle mesurait le
      // plancher du SDK, jamais le nôtre.
      //
      // Ce qui mord : la cellule rendue HORS `PopupMenuItem` (le cas du slot,
      // celui d'IFFD) et en composition HORIZONTALE — sans plancher propre, sa
      // hauteur retombe à celle d'un `Icon` (24 dp). C'est précisément le
      // renoncement a11y que CHAT-4b lève.
      await tester.pumpWidget(_app(ZItemActionsMenu(
        menuBuilder: (context, actions, select) => SizedBox(
          width: 240,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final action in actions)
                ZMenuEntryTile(
                  key: ValueKey<String>('tile-${action.label}'),
                  entry: action.toMenuEntry(),
                  onSelected: () => select(action),
                ),
            ],
          ),
        ),
        actions: <ZItemAction>[_ouvrir()],
      )));
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();

      final taille =
          tester.getSize(find.byKey(const ValueKey('tile-$kOuvrir')));
      expect(taille.height, greaterThanOrEqualTo(48.0),
          reason: '🔴 ${taille.height} dp : la cellule ne porte plus son propre '
              'plancher — l\'hôte qui compose le slot retrouve le défaut a11y '
              'que le socle avait renoncé à couvrir (grille IFFD).');
      expect(taille.width, greaterThanOrEqualTo(48.0));
    });
  });

  group('5. RTL RÉEL — mesuré sur la surface flottante', () {
    /// Écart signé glyphe→libellé DANS LA SURFACE OUVERTE.
    Future<double> ecart(WidgetTester tester, TextDirection direction) async {
      await tester.pumpWidget(_appDirectionnelle(
        ZItemActionsMenu(actions: <ZItemAction>[_ouvrir()]),
        direction,
      ));
      await tester.tap(find.byType(ZItemActionsMenu));
      await tester.pumpAndSettle();

      // 🔴 SONDE ANTI-PIÈGE : la direction doit avoir atteint l'OVERLAY. Lue
      // depuis le contexte du libellé (dans la surface), pas depuis celui du
      // déclencheur — c'est exactement ce que le piège rendrait faux.
      final directionSurface =
          Directionality.of(tester.element(find.text(kOuvrir)));
      expect(directionSurface, direction,
          reason: '🔴 la surface flottante n\'a PAS reçu la direction : la '
              'garde mesurerait le déclencheur et resterait verte à tort.');

      final xIcone =
          tester.getCenter(find.byIcon(Icons.open_in_new).last).dx;
      final xTexte = tester.getCenter(find.text(kOuvrir)).dx;
      return xTexte - xIcone;
    }

    testWidgets('LTR : le glyphe précède le libellé', (tester) async {
      expect(await ecart(tester, TextDirection.ltr), greaterThan(0));
    });

    testWidgets('🔴 RTL : l\'ordre est INVERSÉ dans la surface', (tester) async {
      expect(await ecart(tester, TextDirection.rtl), lessThan(0),
          reason: '🔴 en RTL le glyphe doit passer à DROITE du libellé — une '
              'Row non directionnelle laisserait cet écart POSITIF');
    });
  });
}
