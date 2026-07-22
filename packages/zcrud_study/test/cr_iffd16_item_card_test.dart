// CR-IFFD-16 — carte d'item de base à slots (voie B, arbitrée par l'owner).
//
// Le socle livrait le layout de section et laissait TOUTE la carte d'item à
// l'hôte : chaque application réimplémentait les mêmes ornements, et refaisait
// avec eux le travail d'accessibilité. Ces gardes vérifient les deux moitiés de
// la voie B : le socle apporte bien la structure ET l'a11y, et il n'apporte
// AUCUNE sémantique métier.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  mainCrIffd19to21();
  group('CR-IFFD-16 — slots optionnels, neutres par défaut', () {
    testWidgets('une carte réduite à son titre rend le titre et rien d\'autre',
        (tester) async {
      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(title: 'Cours de chimie'),
      ));
      expect(find.text('Cours de chimie'), findsOneWidget);
      // Aucun slot fourni ⇒ aucun ornement matérialisé.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('chaque slot fourni apparaît', (tester) async {
      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(
          title: 'Note',
          subtitle: 'Modifiée hier',
          leading: Icon(Icons.description_outlined),
          badge: Text('PDF'),
          trailing: Icon(Icons.more_vert),
        ),
      ));
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Modifiée hier'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('🔴 `progress` ÉVINCE `trailing`', (tester) async {
      // Décision explicite : offrir des actions sur une ressource en cours de
      // traitement invite à déclencher une opération concurrente dessus.
      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(
          title: 'Téléversement',
          trailing: Icon(Icons.more_vert),
          progress: CircularProgressIndicator(),
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });

  group('CR-IFFD-16 — accessibilité traitée UNE FOIS par le socle (AD-13)', () {
    testWidgets('🔴 la carte activable est ACTIVABLE au lecteur d\'écran',
        (tester) async {
      // Discriminant : le sous-arbre est exclu de la sémantique pour ne pas
      // annoncer l'item deux fois — ce qui emporte l'action de l'`InkWell`. Sans
      // le `onTap` porté par le nœud de la carte, elle serait annoncée
      // « bouton » et resterait inactivable. Le test invoque l'action SÉMANTIQUE,
      // pas un tap de pointeur : c'est la seule voie qui le prouve.
      var tapped = 0;
      await tester.pumpWidget(_host(
        ZStudyToolsItemCard(title: 'Ouvrir', onTap: () => tapped++),
      ));
      final handle = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel('Ouvrir'));
      await tester.pump();
      expect(tapped, 1);
      handle.dispose();
    });

    testWidgets('la carte annonce titre ET sous-titre comme un tout',
        (tester) async {
      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(title: 'Note', subtitle: 'Hier'),
      ));
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Note, Hier'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('`semanticLabel` prime sur le repli', (tester) async {
      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(
          title: 'cours_chimie_v2.pdf',
          semanticLabel: 'Document PDF, Cours de chimie, version 2',
        ),
      ));
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel('Document PDF, Cours de chimie, version 2'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('🔴 la cible fait au moins 48 dp de haut', (tester) async {
      // Même réduite à un titre court, la carte ne descend jamais sous la
      // cible tactile minimale.
      await tester.pumpWidget(_host(
        const SizedBox(width: 300, child: ZStudyToolsItemCard(title: 'x')),
      ));
      final size = tester.getSize(find.byType(ZStudyToolsItemCard));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('AD-45 — sans `onTap`, PAS de bouton annoncé', (tester) async {
      // L'absence d'activation est structurelle : elle ne se rend pas comme un
      // bouton désactivé, et le lecteur d'écran ne doit pas promettre un geste
      // qui n'existe pas.
      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(title: 'Inerte'),
      ));
      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(find.bySemanticsLabel('Inerte'));
      expect(node.hasFlag(SemanticsFlag.isButton), isFalse);
      handle.dispose();
    });

    testWidgets('RTL — la carte se retourne sans inset codé en dur',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ZStudyToolsItemCard(
              title: 'عنوان',
              leading: Icon(Icons.folder),
            ),
          ),
        ),
      ));
      // En RTL, le `leading` est à DROITE : c'est ce que garantit l'usage
      // exclusif de `Row` + `EdgeInsetsDirectional` (aucun `EdgeInsets.only`).
      final leadingX = tester.getCenter(find.byIcon(Icons.folder)).dx;
      final titleX = tester.getCenter(find.text('عنوان')).dx;
      expect(leadingX, greaterThan(titleX));
    });
  });

  group('CR-IFFD-16 — ce que le socle NE connaît PAS', () {
    testWidgets('le badge est un WIDGET opaque, jamais interprété',
        (tester) async {
      // Garde de frontière : si un jour la carte typait le badge (extension de
      // fichier, type d'item…), elle porterait la nomenclature d'un hôte — ce
      // que la CR interdit explicitement. Un widget arbitraire doit passer.
      await tester.pumpWidget(_host(
        ZStudyToolsItemCard(
          title: 'Item',
          badge: Container(width: 12, height: 12, color: const Color(0xFF00FF00)),
        ),
      ));
      expect(find.byType(Container), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 le `trailing` de l\'hôte reste ATTEIGNABLE au lecteur d\'écran',
        (tester) async {
      // Garde née d'un défaut réel commis ici : exclure TOUT le contenu de la
      // sémantique — pour ne pas annoncer l'item deux fois — retirait du même
      // geste l'accès au menu contextuel de l'hôte. L'accessibilité que cette
      // carte prétend apporter aurait été reprise d'une main.
      var pressed = 0;
      await tester.pumpWidget(_host(
        ZStudyToolsItemCard(
          title: 'Item',
          onTap: () {},
          trailing: IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Actions',
            onPressed: () => pressed++,
          ),
        ),
      ));
      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(find.byType(IconButton));
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'le menu de l\'hôte doit garder son action sémantique propre',
      );
      // Et il doit RÉELLEMENT s'exécuter, pas seulement être annoncé.
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(pressed, 1);
      handle.dispose();
    });

    testWidgets('le `trailing` peut être un menu de l\'hôte avec ses droits',
        (tester) async {
      var chosen = '';
      await tester.pumpWidget(_host(
        ZStudyToolsItemCard(
          title: 'Item',
          trailing: PopupMenuButton<String>(
            onSelected: (v) => chosen = v,
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'del', child: Text('Supprimer')),
            ],
          ),
        ),
      ));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      expect(chosen, 'del');
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CR-IFFD-19/20/21 — trois défauts de CETTE carte, trouvés par IFFD EN LA
// CÂBLANT. Aucun n'était visible depuis la signature.
// ─────────────────────────────────────────────────────────────────────────────
void mainCrIffd19to21() {
  group('CR-IFFD-20 — le slot `progress` ne lève plus', () {
    testWidgets('🔴 un LinearProgressIndicator NU ne lève pas', (tester) async {
      // Le widget de progression le plus évident, et celui de la page legacy
      // d'IFFD. Sans borne, il veut une largeur infinie dans la `Row` et lève
      // « unbounded width ». Un CircularProgressIndicator, lui, passait — d'où
      // un défaut invisible jusqu'à ce qu'un hôte tente la variante linéaire.
      await tester.pumpWidget(_host(
        const SizedBox(
          width: 400,
          child: ZStudyToolsItemCard(
            title: 'Téléversement',
            progress: LinearProgressIndicator(),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('le circulaire continue de passer (non-régression)',
        (tester) async {
      await tester.pumpWidget(_host(
        const SizedBox(
          width: 400,
          child: ZStudyToolsItemCard(
            title: 'x',
            progress: CircularProgressIndicator(),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AD-10 — une largeur max absurde ne casse pas le layout',
        (tester) async {
      await tester.pumpWidget(_host(
        const SizedBox(
          width: 400,
          child: ZStudyToolsItemCard(
            title: 'x',
            progressMaxWidth: -5,
            progress: LinearProgressIndicator(),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('CR-IFFD-21 — l\'éviction de `trailing` est une POLITIQUE', () {
    testWidgets('🔴 `hidesTrailingWhileBusy: false` garde les deux',
        (tester) async {
      // Le cas concret d'IFFD : pendant une génération, le bouton « Lire
      // l'audio » reste rendu — écouter n'est pas une opération CONCURRENTE
      // avec résumer. Seul l'hôte sait lesquelles de ses actions le sont.
      await tester.pumpWidget(_host(
        const SizedBox(
          width: 400,
          child: ZStudyToolsItemCard(
            title: 'Note',
            trailing: Icon(Icons.volume_up),
            progress: CircularProgressIndicator(),
            hidesTrailingWhileBusy: false,
          ),
        ),
      ));
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('le DÉFAUT évince toujours (non-régression)', (tester) async {
      await tester.pumpWidget(_host(
        const SizedBox(
          width: 400,
          child: ZStudyToolsItemCard(
            title: 'Note',
            trailing: Icon(Icons.more_vert),
            progress: CircularProgressIndicator(),
          ),
        ),
      ));
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('sans `progress`, `trailing` est rendu quelle que soit la politique',
        (tester) async {
      await tester.pumpWidget(_host(
        const ZStudyToolsItemCard(
          title: 'Note',
          trailing: Icon(Icons.more_vert),
          hidesTrailingWhileBusy: true,
        ),
      ));
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });
  });

  group('CR-IFFD-19 — la forme de la carte est atteignable par le thème', () {
    ShapeBorder? shapeOf(WidgetTester tester) =>
        tester.widget<Card>(find.byType(Card)).shape;

    testWidgets('🔴 `CardThemeData.shape` du thème est RESPECTÉ',
        (tester) async {
      // Un `shape:` construit en dur l'emporte sur le thème : la carte rendait
      // toute bordure d'hôte inatteignable. Le liseré legacy d'IFFD était le
      // seul écart visuel que le portage ne pouvait pas fermer.
      const themed = RoundedRectangleBorder(
        side: BorderSide(color: Color(0xFF123456), width: 2),
      );
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(cardTheme: const CardThemeData(shape: themed)),
        home: const Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(body: ZStudyToolsItemCard(title: 'x')),
        ),
      ));
      expect(shapeOf(tester), themed);
    });

    testWidgets('🔴 `borderSide` explicite PRIME sur le thème', (tester) async {
      const themed = RoundedRectangleBorder(
        side: BorderSide(color: Color(0xFF123456), width: 2),
      );
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(cardTheme: const CardThemeData(shape: themed)),
        home: const Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: ZStudyToolsItemCard(
              title: 'x',
              borderSide: BorderSide(color: Color(0xFFABCDEF), width: 3),
            ),
          ),
        ),
      ));
      final shape = shapeOf(tester)! as RoundedRectangleBorder;
      expect(shape.side.color, const Color(0xFFABCDEF));
      expect(shape.side.width, 3);
    });

    testWidgets('sans thème NI slot, le rendu antérieur est PRÉSERVÉ',
        (tester) async {
      await tester.pumpWidget(_host(const ZStudyToolsItemCard(title: 'x')));
      final shape = shapeOf(tester)! as RoundedRectangleBorder;
      // Le jeton `radiusM` reste le défaut, et aucun liseré n'apparaît.
      expect(shape.side.style, BorderStyle.none);
    });
  });
}
