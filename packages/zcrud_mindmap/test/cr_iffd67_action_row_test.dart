/// CR-IFFD-67 — gardes de **GÉOMÉTRIE** des actions de nœud + **état vide**.
///
/// 🔴 Pourquoi un fichier séparé, et pourquoi « géométrie » : la garde
/// historique `cibles interactives ≥ 48 dp`
/// (`z_mindmap_outline_editor_test.dart`) était **VACANTE SUR LA LARGEUR**.
/// Mesuré avant correction : chaque bouton d'action mesurait **720 dp de large**
/// (la largeur entière du `Wrap`), donc `size.width >= 48` passait quelle que
/// soit la valeur du plancher. **Preuve d'inertie** : `minWidth: 1` injecté à la
/// place de `config.minTapTarget` → la garde est restée **VERTE**. Exactement le
/// précédent `zcrud_chat/…/z_chat_diffusion_bar.dart`.
///
/// Les gardes ci-dessous ne mesurent donc **jamais une présence** (« il y a un
/// `Wrap` », « il y a un `ConstrainedBox` ») mais la **géométrie rendue** :
/// largeur d'un bouton, nombre de lignes occupées par le `Wrap`, hauteur d'un
/// nœud, position du centre de l'affordance d'état vide. Et pour rendre le
/// plancher tactile **falsifiable**, la garde clé mesure une **égalité exacte à
/// une valeur configurée** (`minTapTarget: 96` ⇒ 96 dp rendus) : un bouton qui
/// reprendrait toute la largeur rendrait 720 et la garde rougirait.
library;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

/// Largeur de référence de la CR (téléphone 720 dp).
const double _kPhone = 720;

/// Forêt mono-nœud (le cas exact de la CR : « un nœud fraîchement ajouté »).
List<ZMindmapNode> _oneNode() =>
    ZMindmapTreeOps.normalizeLevels(<ZMindmapNode>[
      ZMindmapNode(id: 'r', label: 'Root'),
    ]);

Widget _host(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  double textScale = 1.0,
}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Directionality(
          textDirection: direction,
          child: Scaffold(body: ZcrudScope(child: child)),
        ),
      ),
    );

/// Les sept libellés a11y des actions de nœud (ordre du `Wrap`).
List<String> _actionLabels(ZMindmapOutlineLabels l) => <String>[
      l.addChild,
      l.addSibling,
      l.indent,
      l.outdent,
      l.moveUp,
      l.moveDown,
      l.delete,
    ];

/// Nombre de **lignes** réellement occupées par les actions : compte les `dy`
/// distincts des boutons rendus. C'est la mesure que la CR décrit (« une
/// commande par ligne ») — pas la présence d'un `Wrap`, qui existait déjà.
int _actionLineCount(WidgetTester tester, ZMindmapOutlineLabels labels) {
  final tops = <double>{};
  for (final name in _actionLabels(labels)) {
    tops.add(tester.getTopLeft(find.bySemanticsLabel(name).first).dy);
  }
  return tops.length;
}

/// `testWidgets` sur une surface de largeur [width] (défaut : le 720 dp de la CR).
void _tw(
  String description,
  Future<void> Function(WidgetTester) body, {
  double width = _kPhone,
  double height = 1600,
}) {
  testWidgets(description, (tester) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await body(tester);
  });
}

void main() {
  group('CR-IFFD-67 ① — les actions d\'un nœud tiennent sur UNE ligne', () {
    _tw('un bouton d\'action NE S\'APPROPRIE PAS la largeur du Wrap', (t) async {
      await t.pumpWidget(_host(ZMindmapOutlineEditor(roots: _oneNode())));
      await t.pump();

      const labels = ZMindmapOutlineLabels();
      const config = ZMindmapViewConfig();
      for (final name in _actionLabels(labels)) {
        final size = t.getSize(find.bySemanticsLabel(name).first);
        // Plancher AD-13 : la cible reste ≥ 48 dp…
        expect(size.width, greaterThanOrEqualTo(config.minTapTarget),
            reason: 'cible tactile < 48 dp (AD-13) pour « $name »');
        expect(size.height, greaterThanOrEqualTo(config.minTapTarget),
            reason: 'cible tactile < 48 dp (AD-13) pour « $name »');
        // …et le plancher est la contrainte ACTIVE : le bouton ne prend pas
        // toute la largeur offerte (avant correction : 720 dp).
        expect(size.width, lessThan(_kPhone / 2),
            reason: 'le bouton « $name » s\'approprie la largeur du Wrap '
                '(rendu ${size.width} dp sur $_kPhone) — CR-IFFD-67 ①');
      }
    });

    _tw('les SEPT actions occupent UNE SEULE ligne à 720 dp', (t) async {
      await t.pumpWidget(_host(ZMindmapOutlineEditor(roots: _oneNode())));
      await t.pump();
      expect(_actionLineCount(t, const ZMindmapOutlineLabels()), 1,
          reason: 'les actions s\'empilent (avant correction : 7 lignes)');
    });

    _tw('la hauteur d\'UN nœud reste bornée (mesurée 472 dp avant correction)',
        (t) async {
      await t.pumpWidget(_host(ZMindmapOutlineEditor(roots: _oneNode())));
      await t.pump();
      final h = t
          .getSize(find.byKey(const ValueKey<String>('zmindmap-outline-r')))
          .height;
      expect(h, lessThan(250),
          reason: 'un nœud occupe $h dp — la CR mesure ~800 dp sur appareil et '
              '472 dp en harnais AVANT correction (7 actions empilées)');
    });

    _tw('★ FALSIFIABLE — le plancher tactile PILOTE la taille rendue', (t) async {
      // Un plancher à 96 dp doit produire un bouton de 96 dp EXACTEMENT.
      // Si le bouton reprenait la largeur du Wrap, il rendrait 720 et cette
      // égalité rougirait : c'est ce qui rend la garde non-vacante, là où
      // « >= 48 » passait sur un bouton de 720 dp.
      await t.pumpWidget(_host(ZMindmapOutlineEditor(
        roots: _oneNode(),
        config: const ZMindmapViewConfig(minTapTarget: 96),
      )));
      await t.pump();
      final size = t.getSize(find.bySemanticsLabel('Supprimer').first);
      expect(size.width, 96);
      expect(size.height, 96);
    });

    _tw('le Wrap REPREND SON RÔLE : cibles trop larges ⇒ passage à la ligne',
        (t) async {
      // 7 × 120 dp + espacements > 720 dp ⇒ au moins deux lignes, chaque bouton
      // gardant sa taille propre (le `Wrap` répartit, il n'étire pas).
      await t.pumpWidget(_host(ZMindmapOutlineEditor(
        roots: _oneNode(),
        config: const ZMindmapViewConfig(minTapTarget: 120),
      )));
      await t.pump();
      expect(_actionLineCount(t, const ZMindmapOutlineLabels()),
          greaterThanOrEqualTo(2));
      expect(t.getSize(find.bySemanticsLabel('Supprimer').first).width, 120);
    });
  });

  group('CR-IFFD-67 — facteur d\'échelle de texte (cas nominal jamais vérifié)',
      () {
    for (final scale in <double>[1.5, 2.0]) {
      _tw('à ×$scale : cibles ≥ 48 dp, une ligne, aucun débordement',
          (t) async {
        await t.pumpWidget(_host(
          ZMindmapOutlineEditor(roots: _oneNode()),
          textScale: scale,
        ));
        await t.pump();
        expect(t.takeException(), isNull);
        expect(_actionLineCount(t, const ZMindmapOutlineLabels()), 1);
        for (final name in _actionLabels(const ZMindmapOutlineLabels())) {
          final s = t.getSize(find.bySemanticsLabel(name).first);
          expect(s.width, greaterThanOrEqualTo(48));
          expect(s.height, greaterThanOrEqualTo(48));
          expect(s.width, lessThan(_kPhone / 2));
        }
      });
    }
  });

  group('CR-IFFD-67 — RTL (AD-13)', () {
    _tw('en RTL : mêmes tailles, une ligne, premier bouton côté START (droite)',
        (t) async {
      await t.pumpWidget(_host(
        ZMindmapOutlineEditor(roots: _oneNode()),
        direction: TextDirection.rtl,
      ));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(_actionLineCount(t, const ZMindmapOutlineLabels()), 1);

      const labels = ZMindmapOutlineLabels();
      final first = find.bySemanticsLabel(labels.addChild).first;
      final last = find.bySemanticsLabel(labels.delete).first;
      expect(t.getSize(first).width, 48);
      // En RTL le `Wrap` démarre à droite : le premier bouton est à droite du
      // dernier (variante directionnelle réellement appliquée, pas un `left:`).
      expect(t.getTopLeft(first).dx, greaterThan(t.getTopLeft(last).dx));
    });
  });

  group('CR-IFFD-67 ② — état vide (AD-4 / FR-26 / CR-56)', () {
    _tw('SANS injection : affordance CENTRÉE, ≥ 48 dp, et AUCUN texte imposé',
        (t) async {
      await t.pumpWidget(_host(const ZMindmapOutlineEditor()));
      await t.pump();
      expect(t.takeException(), isNull);

      // Deux affordances : la barre d'outils + l'état vide.
      final adds = find.bySemanticsLabel('Ajouter une racine');
      expect(adds, findsNWidgets(2));

      // Celle de l'état vide est CENTRÉE horizontalement (le défaut de la CR :
      // « un + nu de 48 dp dans le coin supérieur gauche »).
      final centerDx = t.getCenter(adds.last).dx;
      expect((centerDx - _kPhone / 2).abs(), lessThan(1),
          reason: 'l\'affordance d\'état vide n\'est pas centrée (dx=$centerDx)');
      final size = t.getSize(adds.last);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      // FR-26/NFR-S7 : le package n'affiche AUCUN libellé qu'il aurait choisi.
      expect(find.byType(Text), findsNothing,
          reason: 'un texte est rendu sans que l\'hôte l\'ait injecté — '
              'libellé codé en dur (FR-26/NFR-S7)');
    });

    _tw('l\'affordance d\'état vide MUTE réellement la forêt (pas un décor)',
        (t) async {
      List<ZMindmapNode>? changed;
      await t.pumpWidget(_host(ZMindmapOutlineEditor(
        onChanged: (f) => changed = f,
      )));
      await t.pump();
      // 🔴 Sans ce préalable la garde serait VACANTE : si l'état vide quittait
      // l'arbre, `.last` retomberait sur le bouton de la barre d'outils et la
      // mutation passerait quand même (constaté en R3 INJ2).
      expect(find.bySemanticsLabel('Ajouter une racine'), findsNWidgets(2));
      await t.tap(find.bySemanticsLabel('Ajouter une racine').last);
      await t.pump();
      expect(changed, isNotNull);
      expect(changed!.length, 1);
      // L'état vide quitte l'arbre dès que la forêt cesse d'être vide.
      expect(find.bySemanticsLabel('Ajouter une racine'), findsOneWidget);
    });

    _tw('l\'état vide DISPARAÎT dès qu\'un nœud existe', (t) async {
      await t.pumpWidget(_host(ZMindmapOutlineEditor(roots: _oneNode())));
      await t.pump();
      expect(find.bySemanticsLabel('Ajouter une racine'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    _tw('textes INJECTÉS : titre, message et libellé d\'action sont rendus',
        (t) async {
      await t.pumpWidget(_host(const ZMindmapOutlineEditor(
        labels: ZMindmapOutlineLabels(
          emptyTitle: 'Aucun noeud',
          emptyMessage: 'Commencez a creer votre carte mentale',
          emptyActionLabel: 'Ajouter un noeud',
        ),
      )));
      await t.pump();
      expect(find.text('Aucun noeud'), findsOneWidget);
      expect(find.text('Commencez a creer votre carte mentale'), findsOneWidget);
      expect(find.text('Ajouter un noeud'), findsOneWidget);
      // Le libellé d'action injecté devient AUSSI l'annonce a11y.
      expect(find.bySemanticsLabel('Ajouter un noeud'), findsOneWidget);
    });

    _tw('a11y : l\'annonce du bouton d\'état vide existe dans l\'arbre SÉMANTIQUE',
        (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(_host(const ZMindmapOutlineEditor()));
      await t.pump();

      // Même précaution qu'au-dessus : `.last` ne doit pas pouvoir retomber sur
      // le bouton de la barre d'outils (garde vacante sinon).
      expect(find.bySemanticsLabel('Ajouter une racine'), findsNWidgets(2));

      // 🔴 On interroge le NŒUD sémantique rendu (l'annonce est posée par un
      // `Semantics` ANCÊTRE du `GestureDetector` : chercher un `Semantics`
      // DESCENDANT du bouton ne prouverait rien).
      final node = t.getSemantics(
        find.bySemanticsLabel('Ajouter une racine').last,
      );
      expect(
        node,
        isSemantics(
          label: 'Ajouter une racine',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('CR-IFFD-67 ③ — priorité paramètre > config > référence', () {
    _tw('RÉFÉRENCE : sans réglage, l\'illustration vaut kZMindmapDefault…',
        (t) async {
      await t.pumpWidget(_host(const ZMindmapOutlineEditor()));
      await t.pump();
      final icon = t.widget<Icon>(find.byIcon(Icons.account_tree_outlined));
      expect(icon.size, kZMindmapDefaultEmptyIconSize);
    });

    _tw('CONFIG : `emptyIconSize` l\'emporte sur la référence', (t) async {
      await t.pumpWidget(_host(const ZMindmapOutlineEditor(
        config: ZMindmapViewConfig(emptyIconSize: 120),
      )));
      await t.pump();
      final icon = t.widget<Icon>(find.byIcon(Icons.account_tree_outlined));
      expect(icon.size, 120);
      expect(icon.size, isNot(kZMindmapDefaultEmptyIconSize));
    });

    _tw('PARAMÈTRE : `emptyBuilder` l\'emporte sur config ET référence',
        (t) async {
      List<ZMindmapNode>? changed;
      await t.pumpWidget(_host(ZMindmapOutlineEditor(
        // La config est fournie ET ignorée : le paramètre prime.
        config: const ZMindmapViewConfig(emptyIconSize: 120),
        onChanged: (f) => changed = f,
        emptyBuilder: (context, onAddRoot) => TextButton(
          key: const ValueKey<String>('hote-empty'),
          onPressed: onAddRoot,
          child: const Text('HOTE'),
        ),
      )));
      await t.pump();

      // L'état vide du socle a totalement disparu.
      expect(find.byIcon(Icons.account_tree_outlined), findsNothing);
      expect(find.byKey(const ValueKey<String>('hote-empty')), findsOneWidget);
      // Seule reste l'affordance de la barre d'outils.
      expect(find.bySemanticsLabel('Ajouter une racine'), findsOneWidget);

      // Et le callback transmis à l'hôte mute RÉELLEMENT la forêt.
      await t.tap(find.byKey(const ValueKey<String>('hote-empty')));
      await t.pump();
      expect(changed, isNotNull);
      expect(changed!.length, 1);
    });
  });
}
