/// Le MONTAGE aux rangs de l'assemblé par défaut — et le chevauchement qu'il
/// ferme.
///
/// L'assemblé posait le bandeau d'édition dans le créneau `capture` (rang 5),
/// hérité d'avant les neuf rangs. Deux conséquences : le bandeau n'était pas à
/// son rang, et un hôte qui fournirait le rang 1 lui-même verrait DEUX
/// bandeaux. Les gardes ci-dessous mesurent des RECTANGLES et des
/// OCCURRENCES — jamais des noms de paramètres, qu'un renommage rendrait
/// verts pour rien.
///
/// * **MNT-I** — INERTIE : un hôte qui ne fournit aucun contrôleur de pièces
///   jointes retrouve l'arbre d'avant, au repos comme au rendu. Mesurée en
///   ABSOLU (nombre d'enfants du cadre, décalage du champ sous le haut du
///   cadre), jamais par comparaison de deux arbres qu'une même injection
///   déplacerait tous les deux.
/// * **MNT-D** — NON-DUPLICATION : le bandeau d'édition est monté UNE fois.
///   C'est la garde qui ferme le danger laissé ouvert.
/// * **MNT-R** — RANGS EFFECTIFS : bandeau (1) au-dessus de la progression
///   (2), au-dessus de l'aperçu (4), au-dessus de la dictée (5), au-dessus du
///   champ — et tout cela DANS le cadre.
/// * **MNT-A** — ABSENCE (AD-4) : sans contrôleur, aucun nœud d'aperçu ni de
///   progression n'est intercalé.
/// * **MNT-S** — le geste de relecture de texte : offert, atteignable,
///   ≥ 48 dp, absent quand l'hôte ne le câble pas, absent sur une pièce qui
///   n'est pas une image.
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

const Color _cursor = Color(0xFF123456);

/// LE CADRE — la marge que `ZChatComposer` pose autour de ses rangs. C'est ce
/// nœud qui matérialise la boîte, pas le widget.
Finder _frameFinder() => find
    .descendant(of: find.byType(ZChatComposer), matching: find.byType(Padding))
    .first;

/// La `Column` DES RANGS — celle qui vit dans le cadre, jamais une autre.
Finder _columnFinder() =>
    find.descendant(of: _frameFinder(), matching: find.byType(Column)).first;

Column _column(WidgetTester tester) =>
    tester.widget<Column>(_columnFinder());

Rect _frame(WidgetTester tester) => tester.getRect(_frameFinder());

Rect _fieldRect(WidgetTester tester) =>
    tester.getRect(find.byType(EditableText));

ZPendingAttachment _png({String name = 'a.png'}) => ZPendingAttachment(
  bytes: Uint8List.fromList(<int>[1, 2, 3]),
  fileName: name,
  mimeType: 'image/png',
);

ZPendingAttachment _pdf() => ZPendingAttachment(
  bytes: Uint8List.fromList(<int>[1, 2, 3]),
  fileName: 'a.pdf',
  mimeType: 'application/pdf',
);

/// Le libellé de repli du rang 2 — le socle n'a pas de compteur d'octets.
const String _kUploading = 'Téléversement en cours';

/// Le libellé de repli du geste de relecture.
const String _kScan = 'Extraire le texte d\'une image';

void main() {
  group('🔴 MNT-I — INERTIE de l\'hôte passif', () {
    testWidgets(
      'MNT-I1 sans contrôleur de pièces jointes : le cadre porte le bandeau '
      'et l\'ancre, et RIEN ne s\'intercale au-dessus du champ',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);

        await tester.pumpWidget(
          harness(
            ZDefaultChatComposer(
              controller: rig.controller,
              settings: ZChatSettingsController(),
              cursorColor: _cursor,
            ),
          ),
        );

        // ABSOLU : trois enfants — le bandeau (rendu vide hors édition),
        // l'ancre, la bande d'accessoires. Ni aperçu, ni progression, ni
        // créneau de capture.
        final List<Widget> children = _column(tester).children;
        expect(
          children,
          hasLength(3),
          reason: '🔴 un rang s\'est intercalé chez un hôte qui n\'a rien '
              'demandé (AD-4)',
        );
        expect(
          children[0],
          isA<ZChatComposerEditingBanner>(),
          reason: '🔴 le premier enfant du cadre n\'est plus le bandeau '
              'd\'édition : le rang 1 a changé d\'occupant',
        );
        expect(
          children[1],
          isA<Row>(),
          reason: '🔴 l\'ancre n\'est plus le DEUXIÈME enfant : un rang '
              's\'est glissé entre le bandeau et le champ',
        );
        // Le sujet est la `Column` DES RANGS et l'ANCRE, pas le cadre :
        // comparer au cadre mesurerait sa marge, une propriété que ce lot ne
        // touche pas — la garde serait ancrée au mauvais nœud.
        expect(
          tester.getRect(find.byWidget(children[1])).top -
              tester.getRect(_columnFinder()).top,
          moreOrLessEquals(0, epsilon: 0.5),
          reason: '🔴 quelque chose OCCUPE de la hauteur au-dessus de '
              'l\'ancre chez un hôte passif',
        );
      },
    );

    testWidgets(
      'MNT-A sans contrôleur : aucun nœud d\'aperçu ni d\'annonce de '
      'téléversement dans l\'arbre',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);

        await tester.pumpWidget(
          harness(
            ZDefaultChatComposer(
              controller: rig.controller,
              settings: ZChatSettingsController(),
              cursorColor: _cursor,
            ),
          ),
        );
        expect(find.byType(ZChatAttachmentStrip), findsNothing);
        expect(find.text(_kUploading), findsNothing);
      },
    );
  });

  group('🔴 MNT-D — le bandeau d\'édition est monté UNE FOIS', () {
    testWidgets(
      'MNT-D1 en mode édition, exactement UN bandeau — pas un par créneau',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        rig.controller.startEditing(messageId: 'm1', originalText: 'avant');

        await tester.pumpWidget(
          harness(
            ZDefaultChatComposer(
              controller: rig.controller,
              settings: ZChatSettingsController(),
              cursorColor: _cursor,
            ),
          ),
        );
        expect(
          find.byType(ZChatComposerEditingBanner),
          findsOneWidget,
          reason: '🔴 le bandeau d\'édition est monté DEUX FOIS : le créneau '
              'hérité (capture) n\'a pas été libéré',
        );
      },
    );

    testWidgets(
      'MNT-D2 avec un bandeau d\'HÔTE ET un créneau de dictée : le bandeau '
      'd\'hôte apparaît une seule fois, et la dictée reste au rang 5',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        rig.controller.startEditing(messageId: 'm1', originalText: 'avant');

        const Key hostBanner = ValueKey<String>('mnt-host-banner');
        const Key hostDictation = ValueKey<String>('mnt-host-dictation');

        await tester.pumpWidget(
          harness(
            ZDefaultChatComposer(
              controller: rig.controller,
              settings: ZChatSettingsController(),
              cursorColor: _cursor,
              editingBannerBuilder:
                  (BuildContext context, ZChatComposerSlot slot) =>
                      const SizedBox(key: hostBanner, height: 20),
              dictation: (BuildContext context, ZChatComposerSlot slot) =>
                  const SizedBox(key: hostDictation, height: 14),
            ),
          ),
        );

        expect(
          find.byKey(hostBanner),
          findsOneWidget,
          reason: '🔴 le bandeau d\'HÔTE est rendu deux fois : c\'est le '
              'chevauchement que ce lot ferme',
        );
        final Rect banner = tester.getRect(find.byKey(hostBanner));
        final Rect dictate = tester.getRect(find.byKey(hostDictation));
        expect(
          banner.bottom,
          lessThanOrEqualTo(dictate.top),
          reason: '🔴 le bandeau (rang 1) n\'est pas AU-DESSUS de la dictée '
              '(rang 5)',
        );
        expect(
          dictate.bottom,
          lessThanOrEqualTo(_fieldRect(tester).top),
          reason: '🔴 la dictée n\'est plus au-dessus du champ',
        );
      },
    );
  });

  group('🔴 MNT-R — les rangs EFFECTIFS de ce que l\'assemblé monte', () {
    testWidgets(
      'MNT-R1 bandeau (1) < progression (2) < aperçu (4) < champ, et tout '
      'DANS le cadre',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        final ZChatAttachmentController attachments =
            ZChatAttachmentController();
        addTearDown(attachments.dispose);
        attachments.add(_png());
        rig.controller.startEditing(messageId: 'm1', originalText: 'avant');

        await tester.pumpWidget(
          harness(
            ZDefaultChatComposer(
              controller: rig.controller,
              settings: ZChatSettingsController(),
              cursorColor: _cursor,
              attachments: attachments,
              // La progression est pilotée par une tranche d'hôte dans cette
              // mesure : le sujet ici est le RANG, pas le câblage — déjà
              // mesuré par la garde de la tranche de téléversement.
              progressBuilder:
                  (BuildContext context, ZChatComposerSlot slot) =>
                      const SizedBox(
                        key: ValueKey<String>('mnt-progress'),
                        height: 10,
                      ),
            ),
          ),
        );

        final Rect frame = _frame(tester);
        final Rect banner = tester.getRect(
          find.byType(ZChatComposerEditingBanner),
        );
        final Rect progress = tester.getRect(
          find.byKey(const ValueKey<String>('mnt-progress')),
        );
        final Rect strip = tester.getRect(find.byType(ZChatAttachmentStrip));
        final Rect field = _fieldRect(tester);

        expect(banner.bottom, lessThanOrEqualTo(progress.top),
            reason: '🔴 le bandeau (rang 1) n\'est pas au-dessus de la '
                'progression (rang 2)');
        expect(progress.bottom, lessThanOrEqualTo(strip.top),
            reason: '🔴 la progression (rang 2) n\'est pas au-dessus de '
                'l\'aperçu (rang 4)');
        expect(strip.bottom, lessThanOrEqualTo(field.top),
            reason: '🔴 l\'aperçu (rang 4) n\'est pas au-dessus du champ');
        expect(banner.top, lessThan(progress.top));
        expect(progress.top, lessThan(strip.top));
        expect(
          frame.contains(strip.topLeft) &&
              frame.contains(strip.bottomRight - const Offset(0.5, 0.5)),
          isTrue,
          reason: '🔴 l\'aperçu est SORTI de la boîte : il est à côté du '
              'cadre, pas dedans',
        );
      },
    );

    testWidgets(
      'MNT-R2 une vignette ajoutée POUSSE le champ vers le bas — elle ne se '
      'superpose pas',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        final ZChatAttachmentController attachments =
            ZChatAttachmentController();
        addTearDown(attachments.dispose);

        await tester.pumpWidget(
          harness(
            ZDefaultChatComposer(
              controller: rig.controller,
              settings: ZChatSettingsController(),
              cursorColor: _cursor,
              attachments: attachments,
            ),
          ),
        );
        final double before = _fieldRect(tester).top;
        final double frameBefore = _frame(tester).height;

        attachments.add(_png());
        await tester.pump();

        final double grown = _fieldRect(tester).top - before;
        expect(
          grown,
          greaterThan(0),
          reason: '🔴 la vignette ne POUSSE pas le champ : le rang 4 se '
              'superpose au lieu de s\'empiler',
        );
        expect(
          _frame(tester).height - frameBefore,
          moreOrLessEquals(grown, epsilon: 0.5),
          reason: '🔴 le CADRE n\'a pas absorbé la vignette : elle a débordé',
        );
      },
    );
  });

  group('🔴 MNT-S — le geste de relecture de texte sur une vignette', () {
    testWidgets(
      'MNT-S1 câblé : l\'affordance est un BOUTON annoncé, sa cible fait '
      '≥ 48 dp, et elle rend la pièce exacte',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        final ZChatAttachmentController attachments =
            ZChatAttachmentController();
        addTearDown(attachments.dispose);
        attachments.add(_png(name: 'facture.png'));

        final List<ZPendingAttachment> scanned = <ZPendingAttachment>[];
        final SemanticsHandle handle = tester.ensureSemantics();

        await tester.pumpWidget(
          harness(
            ZDefaultChatComposer(
              controller: rig.controller,
              settings: ZChatSettingsController(),
              cursorColor: _cursor,
              attachments: attachments,
              onScanAttachment: scanned.add,
            ),
            // Libellés d'UNE LETTRE, injectés par le registre. Sans eux, le
            // texte de repli est assez large et assez haut pour atteindre
            // 48 dp TOUT SEUL : la mesure du plancher tactile serait
            // inerte — vraie quoi qu'il arrive au `ConstrainedBox`.
            labels: const <String, String>{
              'zchat.scanText': 'S',
              'zchat.removeAttachment': 'R',
            },
          ),
        );

        final Finder target = find.text('S');
        expect(target, findsOneWidget,
            reason: '🔴 le geste de relecture n\'est pas offert');

        // Le SUJET de la cible est le nœud qui REÇOIT le tap, pas un
        // conteneur choisi au hasard parmi ses ancêtres.
        final Size box = tester.getSize(
          find.ancestor(of: target, matching: find.byType(GestureDetector)).first,
        );
        expect(box.width, greaterThanOrEqualTo(48),
            reason: '🔴 cible tactile sous 48 dp en largeur (AD-13)');
        expect(box.height, greaterThanOrEqualTo(48),
            reason: '🔴 cible tactile sous 48 dp en hauteur (AD-13)');

        // Le SUJET de la sémantique est le nœud PORTANT le libellé — pas le
        // widget `Text`, dont l\'exclusion ferait remonter `getSemantics` à
        // un ancêtre quelconque et rendrait la garde muette.
        final Finder node = find.bySemanticsLabel('S');
        expect(node, findsOneWidget);
        expect(
          tester.getSemantics(node),
          matchesSemantics(label: 'S', isButton: true, hasTapAction: true),
          reason: '🔴 le geste n\'est pas un BOUTON annoncé : il est muet '
              'pour un lecteur d\'écran (AD-13)',
        );

        await tester.tap(target);
        await tester.pump();
        expect(scanned, hasLength(1));
        expect(scanned.single.fileName, 'facture.png',
            reason: '🔴 le geste ne rend pas la pièce sur laquelle il a été '
                'exercé');
        handle.dispose();
      },
    );

    testWidgets(
      'MNT-S2 non câblé : AUCUNE affordance n\'entre dans l\'arbre (AD-4)',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        final ZChatAttachmentController attachments =
            ZChatAttachmentController();
        addTearDown(attachments.dispose);
        attachments.add(_png());

        await tester.pumpWidget(
          harness(
            ZDefaultChatComposer(
              controller: rig.controller,
              settings: ZChatSettingsController(),
              cursorColor: _cursor,
              attachments: attachments,
            ),
          ),
        );
        expect(find.text(_kScan), findsNothing,
            reason: '🔴 un bouton INERTE est offert : le socle n\'a pas de '
                'moteur de reconnaissance');
      },
    );

    testWidgets(
      'MNT-S3 sur une pièce qui n\'est PAS une image : aucune promesse',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        final ZChatAttachmentController attachments =
            ZChatAttachmentController();
        addTearDown(attachments.dispose);
        attachments.add(_pdf());

        await tester.pumpWidget(
          harness(
            ZDefaultChatComposer(
              controller: rig.controller,
              settings: ZChatSettingsController(),
              cursorColor: _cursor,
              attachments: attachments,
              onScanAttachment: (ZPendingAttachment _) {},
            ),
          ),
        );
        expect(find.text(_kScan), findsNothing);
        // Contre-preuve : la vignette EST là — la mesure n'est pas vide.
        expect(find.text('a.pdf'), findsOneWidget);
      },
    );
  });
}
