/// La tranche de TÉLÉVERSEMENT du contrôleur de pièces jointes.
///
/// Ce que ces gardes mesurent, et pourquoi cette forme :
///
/// * **UPL-1** — la tranche passe à `true` PENDANT le transfert et revient à
///   `false` APRÈS. Le sujet est mesuré **en vol** (l'uploader est suspendu
///   sur un `Completer`), jamais après coup : une garde qui ne lirait que
///   l'état final ne distinguerait pas une tranche qui monte d'une tranche
///   qui n'a jamais bougé.
/// * **UPL-2** — le chemin d'ÉCHEC (`Left` du serveur) remet au repos.
/// * **UPL-3** — le chemin d'EXCEPTION d'hôte remet au repos (AD-10) : c'est
///   celui qu'un `try/catch` sans `finally` laisse allumé pour toujours.
/// * **UPL-4** — deux transferts simultanés : le premier qui finit NE remet
///   PAS au repos. C'est le défaut qu'un simple booléen produirait.
/// * **UPL-5** — GRANULARITÉ : la tranche notifie SEULE (ni `pending`, ni
///   `uploaded`, ni `lastFailure`, ni le canal global ne bougent au seul fait
///   qu'un octet monte).
/// * **UPL-7** — la tranche alimente l'état OCCUPÉ du bouton d'envoi par la
///   signature EXISTANTE de l'affordance d'envoi : rien n'est ajouté à cette
///   pièce, la tranche lui suffit.
/// * **UPL-6** — MONTÉE : dans un composer réel, un cycle de la tranche ne
///   reconstruit pas le champ de saisie et ne lui prend ni son focus, ni son
///   texte. Le sujet est l'`EditableText` RENDU, pas le widget déclaré.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

ZPendingAttachment _png({String name = 'a.png'}) => ZPendingAttachment(
  bytes: Uint8List.fromList(<int>[1, 2, 3]),
  fileName: name,
  mimeType: 'image/png',
);

ZChatAttachment _stored(String id) =>
    ZChatAttachment(id: id, url: 'https://example.invalid/$id');

/// Uploader SUSPENDU : il rend la main quand le test le décide, ce qui laisse
/// mesurer l'état PENDANT le transfert.
class _GatedUploader extends ZChatAttachmentUploader {
  _GatedUploader();

  final List<Completer<ZResult<ZChatAttachment>>> gates =
      <Completer<ZResult<ZChatAttachment>>>[];

  @override
  Future<ZResult<ZChatAttachment>> upload(ZPendingAttachment pending) {
    final Completer<ZResult<ZChatAttachment>> gate =
        Completer<ZResult<ZChatAttachment>>();
    gates.add(gate);
    return gate.future;
  }
}

/// Uploader qui LÈVE — le chemin AD-10.
class _ThrowingUploader extends ZChatAttachmentUploader {
  const _ThrowingUploader();

  @override
  Future<ZResult<ZChatAttachment>> upload(ZPendingAttachment pending) async {
    throw StateError('boom');
  }
}

void main() {
  group('🔴 UPL — la tranche de téléversement', () {
    test('UPL-1 vraie PENDANT le transfert, fausse APRÈS', () async {
      final _GatedUploader uploader = _GatedUploader();
      final ZChatAttachmentController c = ZChatAttachmentController(
        uploader: uploader,
      );
      addTearDown(c.dispose);

      expect(c.uploading.value, isFalse, reason: 'au repos avant tout appel');

      final Future<ZResult<ZChatAttachment>> run = c.upload(_png());
      await Future<void>.delayed(Duration.zero);
      // EN VOL — la seule fenêtre où la tranche a une valeur à prouver.
      expect(c.uploading.value, isTrue);

      uploader.gates.single.complete(
        Right<ZFailure, ZChatAttachment>(_stored('x')),
      );
      await run;
      expect(c.uploading.value, isFalse);
    });

    test('UPL-2 un refus du serveur remet au repos', () async {
      final _GatedUploader uploader = _GatedUploader();
      final ZChatAttachmentController c = ZChatAttachmentController(
        uploader: uploader,
      );
      addTearDown(c.dispose);

      final Future<ZResult<ZChatAttachment>> run = c.upload(_png());
      await Future<void>.delayed(Duration.zero);
      expect(c.uploading.value, isTrue);

      uploader.gates.single.complete(
        const Left<ZFailure, ZChatAttachment>(ZServerFailure('refusé')),
      );
      final ZResult<ZChatAttachment> result = await run;
      expect(result.isLeft(), isTrue);
      expect(c.uploading.value, isFalse);
    });

    test('UPL-3 un uploader qui LÈVE remet au repos (AD-10)', () async {
      final ZChatAttachmentController c = ZChatAttachmentController(
        uploader: const _ThrowingUploader(),
      );
      addTearDown(c.dispose);

      final ZResult<ZChatAttachment> result = await c.upload(_png());
      expect(result.isLeft(), isTrue);
      expect(
        c.uploading.value,
        isFalse,
        reason: 'une tranche restée allumée bloquerait l\'envoi pour toujours',
      );
    });

    test('UPL-4 deux transferts : le premier fini ne remet PAS au repos',
        () async {
      final _GatedUploader uploader = _GatedUploader();
      final ZChatAttachmentController c = ZChatAttachmentController(
        uploader: uploader,
      );
      addTearDown(c.dispose);

      final Future<ZResult<ZChatAttachment>> a = c.upload(_png(name: 'a.png'));
      final Future<ZResult<ZChatAttachment>> b = c.upload(_png(name: 'b.png'));
      await Future<void>.delayed(Duration.zero);
      expect(uploader.gates.length, 2);
      expect(c.uploading.value, isTrue);

      uploader.gates[0].complete(
        Right<ZFailure, ZChatAttachment>(_stored('a')),
      );
      await a;
      expect(
        c.uploading.value,
        isTrue,
        reason: 'le second transfert monte encore',
      );

      uploader.gates[1].complete(
        Right<ZFailure, ZChatAttachment>(_stored('b')),
      );
      await b;
      expect(c.uploading.value, isFalse);
    });

    test('UPL-5 elle notifie SEULE — les autres tranches ne bougent pas',
        () async {
      final _GatedUploader uploader = _GatedUploader();
      final ZChatAttachmentController c = ZChatAttachmentController(
        uploader: uploader,
      );
      addTearDown(c.dispose);

      int uploading = 0;
      int pending = 0;
      int uploaded = 0;
      int failure = 0;
      int global = 0;
      c.uploading.addListener(() => uploading++);
      c.pending.addListener(() => pending++);
      c.uploaded.addListener(() => uploaded++);
      c.lastFailure.addListener(() => failure++);
      c.addListener(() => global++);

      final Future<ZResult<ZChatAttachment>> run = c.upload(_png());
      await Future<void>.delayed(Duration.zero);
      expect(uploading, 1);
      expect(pending, 0);
      expect(uploaded, 0);
      expect(failure, 0);
      expect(global, 0, reason: 'le canal global reste structurel');

      uploader.gates.single.complete(
        Right<ZFailure, ZChatAttachment>(_stored('x')),
      );
      await run;
      expect(uploading, 2, reason: 'montée puis retour au repos');
      expect(global, 0);
    });
  });

  group('🔴 UPL — montée dans un composer réel', () {
    testWidgets(
      'UPL-7 la tranche pilote l\'état OCCUPÉ de l\'envoi par la signature '
      'existante — sans rien y ajouter',
      (WidgetTester tester) async {
        final _GatedUploader uploader = _GatedUploader();
        final ZChatAttachmentController attachments = ZChatAttachmentController(
          uploader: uploader,
        );
        addTearDown(attachments.dispose);
        final rig = buildController();
        addTearDown(rig.controller.dispose);

        await tester.pumpWidget(
          harness(
            ZDefaultChatComposer(
              controller: rig.controller,
              settings: ZChatSettingsController(),
              cursorColor: const Color(0xFF112233),
              attachments: attachments,
              sendBuilder: (BuildContext context, ZChatComposerSlot slot) =>
                  ZChatComposerSendControl(
                    slot: slot,
                    // LE point de la garde : `busy` accepte la tranche telle
                    // quelle. Si la pièce d'envoi avait dû changer de
                    // signature, cette ligne ne compilerait pas.
                    busy: attachments.uploading,
                    glyphs: const ZChatComposerSendGlyphs(
                      idle: Text('repos'),
                      busy: Text('occupé'),
                    ),
                  ),
            ),
          ),
        );

        expect(find.text('repos'), findsOneWidget);
        expect(find.text('occupé'), findsNothing);

        final Future<ZResult<ZChatAttachment>> run = attachments.upload(_png());
        await tester.pump();
        expect(find.text('occupé'), findsOneWidget,
            reason: '🔴 l\'envoi n\'a pas vu le téléversement');
        expect(find.text('repos'), findsNothing);

        uploader.gates.single.complete(
          Right<ZFailure, ZChatAttachment>(_stored('x')),
        );
        await run;
        await tester.pump();
        expect(find.text('repos'), findsOneWidget,
            reason: '🔴 l\'état occupé SURVIT au transfert');
      },
    );

    testWidgets(
      'UPL-6 la tranche pilote le rang 2 SANS reconstruire le champ : ni '
      'focus, ni texte, ni position du curseur perdus',
      (WidgetTester tester) async {
        final _GatedUploader uploader = _GatedUploader();
        final ZChatAttachmentController attachments = ZChatAttachmentController(
          uploader: uploader,
        );
        addTearDown(attachments.dispose);
        final rig = buildController();
        addTearDown(rig.controller.dispose);

        await tester.pumpWidget(
          harness(
            ZDefaultChatComposer(
              controller: rig.controller,
              settings: ZChatSettingsController(),
              cursorColor: const Color(0xFF112233),
              attachments: attachments,
            ),
          ),
        );

        await tester.enterText(find.byType(EditableText), 'brouillon');
        await tester.pump();
        final FocusNode focus =
            tester.widget<EditableText>(find.byType(EditableText)).focusNode;
        focus.requestFocus();
        rig.controller.composer.selection =
            const TextSelection.collapsed(offset: 4);
        await tester.pump();
        expect(focus.hasFocus, isTrue,
            reason: 'préalable : le champ n\'a pas le focus');

        // Le SUJET est l'instance de widget RENDUE — pas l'Element, qui
        // survit à une reconstruction du parent et rendrait la garde muette.
        final EditableText before =
            tester.widget<EditableText>(find.byType(EditableText));
        final Finder announce = find.text('Téléversement en cours');
        expect(announce, findsNothing, reason: 'au repos, le rang 2 est vide');

        final Future<ZResult<ZChatAttachment>> run = attachments.upload(_png());
        await tester.pump();

        // Contre-preuve : sans elle, tout ce qui suit serait vert parce que
        // RIEN n'a bougé.
        expect(
          announce,
          findsOneWidget,
          reason: 'préalable : le rang 2 n\'a pas réagi, la mesure est vide',
        );
        expect(
          identical(
            before,
            tester.widget<EditableText>(find.byType(EditableText)),
          ),
          isTrue,
          reason: '🔴 le champ a été RECONSTRUIT parce qu\'un octet monte : '
              'l\'abonnement remonte AU-DESSUS du champ (SM-1)',
        );
        expect(focus.hasFocus, isTrue,
            reason: '🔴 le champ a PERDU LE FOCUS pendant un téléversement');
        expect(rig.controller.composer.text, 'brouillon');
        expect(
          rig.controller.composer.selection,
          const TextSelection.collapsed(offset: 4),
          reason: '🔴 le curseur a SAUTÉ pendant un téléversement',
        );

        uploader.gates.single.complete(
          Right<ZFailure, ZChatAttachment>(_stored('x')),
        );
        await run;
        await tester.pump();
        expect(announce, findsNothing,
            reason: '🔴 l\'annonce du rang 2 SURVIT au transfert');
        expect(
          identical(
            before,
            tester.widget<EditableText>(find.byType(EditableText)),
          ),
          isTrue,
        );
        expect(focus.hasFocus, isTrue);
      },
    );
  });
}
