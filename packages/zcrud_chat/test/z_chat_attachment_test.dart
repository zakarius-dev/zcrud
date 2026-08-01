/// Comportement des **pièces jointes** — CHAT-5.
///
/// Ce que ces gardes prouvent : le contrôleur porté de lex tient ses bornes,
/// distingue l'annulation de l'échec, câble `ZChatAttachment` du **kernel** en
/// sortie de téléversement, relaie le verdict du SERVEUR sans le rejouer, et —
/// AD-10 — ne laisse **jamais** une pièce jointe emporter la conversation.
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

Uint8List _bytes(int n) => Uint8List.fromList(List<int>.filled(n, 0x41));

ZPendingAttachment _png({int size = 16, String name = 'a.png'}) =>
    ZPendingAttachment(
      bytes: _bytes(size),
      fileName: name,
      mimeType: 'image/png',
    );

/// Picker scriptable — il joue exactement ce qu'on lui dit, y compris LEVER.
class _ScriptedPicker extends ZChatAttachmentPicker {
  _ScriptedPicker({this.result, this.throws = false});

  final ZResult<ZPendingAttachment?>? result;
  final bool throws;
  final List<ZChatAttachmentSource> calls = <ZChatAttachmentSource>[];

  @override
  Future<ZResult<ZPendingAttachment?>> pick(
    ZChatAttachmentSource source,
  ) async {
    calls.add(source);
    if (throws) throw StateError('picker exploded');
    return result ?? const Right<ZFailure, ZPendingAttachment?>(null);
  }
}

/// Téléverseur scriptable — il peut réussir, refuser (verdict serveur) ou lever.
class _ScriptedUploader extends ZChatAttachmentUploader {
  _ScriptedUploader({this.result, this.throws = false});

  final ZResult<ZChatAttachment>? result;
  final bool throws;
  int calls = 0;

  @override
  Future<ZResult<ZChatAttachment>> upload(ZPendingAttachment pending) async {
    calls++;
    if (throws) throw StateError('uploader exploded');
    return result ??
        Right<ZFailure, ZChatAttachment>(
          ZChatAttachment(
            id: 'srv-${pending.fileName}',
            url: 'https://example.invalid/${pending.fileName}',
            mimeType: pending.mimeType,
            fileName: pending.fileName,
          ),
        );
  }
}

void main() {
  group('🔴 C5-A1 — les bornes de lex, portées à l\'identique', () {
    test('les trois valeurs de lex sont conservées', () {
      // 🔴 Si ces constantes bougent, c'est un CHANGEMENT DE PRODUIT, pas un
      // détail : le socle accepterait des pièces que lex refusait.
      expect(kZChatDefaultMaxAttachments, 5);
      expect(kZChatDefaultMaxAttachmentBytes, 10 * 1024 * 1024);
      expect(kZChatDefaultAllowedAttachmentMimeTypes, <String>{
        'image/png',
        'image/jpeg',
        'application/pdf',
      });
    });

    test('plafond de fichiers : le 6ᵉ est refusé, les 5 premiers restent', () {
      final ZChatAttachmentController c = ZChatAttachmentController();
      addTearDown(c.dispose);
      for (int i = 0; i < 5; i++) {
        expect(c.add(_png(name: 'f$i.png')).isRight(), isTrue);
      }
      expect(c.canAddMore, isFalse);
      final ZResult<ZPendingAttachment> sixth = c.add(_png(name: 'f5.png'));
      expect(sixth.isLeft(), isTrue);
      expect(
        (sixth.swap().getOrElse(() => throw StateError('x'))
                as ZChatAttachmentFailure)
            .reason,
        ZChatAttachmentRejection.maxFilesReached,
      );
      expect(c.pending.value, hasLength(5),
          reason: '🔴 un refus ne doit RIEN changer à l\'état existant');
    });

    test('type MIME hors table ⇒ refus typé', () {
      final ZChatAttachmentController c = ZChatAttachmentController();
      addTearDown(c.dispose);
      final ZResult<ZPendingAttachment> r = c.add(
        ZPendingAttachment(
          bytes: _bytes(4),
          fileName: 'x.exe',
          mimeType: 'application/x-msdownload',
        ),
      );
      expect(r.isLeft(), isTrue);
      expect(c.lastFailure.value?.reason,
          ZChatAttachmentRejection.unsupportedType);
      expect(c.pending.value, isEmpty);
    });

    test('taille au-delà du plafond ⇒ refus typé', () {
      final ZChatAttachmentController c = ZChatAttachmentController(
        maxFileSizeBytes: 8,
      );
      addTearDown(c.dispose);
      expect(c.add(_png(size: 9)).isLeft(), isTrue);
      expect(c.lastFailure.value?.reason,
          ZChatAttachmentRejection.fileTooLarge);
      // …et la borne est INCLUSIVE, comme chez lex (`> maxFileSize`).
      expect(c.add(_png(size: 8)).isRight(), isTrue);
    });

    test('l\'ORDRE de validation de lex est conservé : plafond AVANT type', () {
      // 🔴 Ce n'est pas cosmétique : avec l'ordre inverse, un 6ᵉ fichier de
      // mauvais type serait signalé « type invalide » alors que la vraie cause
      // est le plafond — l'utilisateur convertirait son fichier pour rien.
      final ZChatAttachmentController c = ZChatAttachmentController(maxFiles: 1);
      addTearDown(c.dispose);
      c.add(_png());
      final ZResult<ZPendingAttachment> r = c.add(
        ZPendingAttachment(
          bytes: _bytes(2),
          fileName: 'y.exe',
          mimeType: 'application/x-msdownload',
        ),
      );
      expect(
        (r.swap().getOrElse(() => throw StateError('x'))
                as ZChatAttachmentFailure)
            .reason,
        ZChatAttachmentRejection.maxFilesReached,
      );
    });

    test('`sizeBytes` est DÉRIVÉ — il ne peut pas mentir sur les octets', () {
      // lex portait un champ `sizeBytes` À CÔTÉ de `bytes` : deux sources pour
      // un même fait, et c'est celle qui pouvait mentir que la validation lisait.
      expect(_png(size: 123).sizeBytes, 123);
    });
  });

  group('🔴 C5-A2 — annulation ≠ échec (l\'ambiguïté de lex, levée)', () {
    test('l\'utilisateur annule ⇒ `Right(null)`, AUCUN échec enregistré', () {
      final _ScriptedPicker picker = _ScriptedPicker();
      final ZChatAttachmentController c = ZChatAttachmentController(
        picker: picker,
      );
      addTearDown(c.dispose);
      return c.pick(ZChatAttachmentSource.files).then((
        ZResult<ZPendingAttachment?> r,
      ) {
        expect(r.isRight(), isTrue);
        expect(r.getOrElse(() => _png()), isNull);
        expect(c.lastFailure.value, isNull,
            reason: '🔴 chez lex, `null` signifiait à la fois « ajouté » et '
                '« annulé » : l\'appelant ne pouvait pas distinguer les deux');
        expect(c.pending.value, isEmpty);
      });
    });

    test('le picker échoue ⇒ `Left`, cause RELAYÉE', () async {
      final ZChatAttachmentController c = ZChatAttachmentController(
        picker: _ScriptedPicker(
          result: const Left<ZFailure, ZPendingAttachment?>(
            ZDomainFailure('permission denied'),
          ),
        ),
      );
      addTearDown(c.dispose);
      final ZResult<ZPendingAttachment?> r = await c.pick(
        ZChatAttachmentSource.camera,
      );
      expect(r.isLeft(), isTrue);
      expect(c.lastFailure.value?.reason, ZChatAttachmentRejection.pickFailed);
      expect(c.lastFailure.value?.cause,
          const ZDomainFailure('permission denied'));
    });

    test('les trois sources VIVANTES de lex sont atteignables', () async {
      final _ScriptedPicker picker = _ScriptedPicker();
      final ZChatAttachmentController c = ZChatAttachmentController(
        picker: picker,
      );
      addTearDown(c.dispose);
      for (final ZChatAttachmentSource s in ZChatAttachmentSource.values) {
        await c.pick(s);
      }
      expect(picker.calls, ZChatAttachmentSource.values,
          reason: '🔴 une source déclarée mais jamais transmise au picker est '
              'une option MORTE — les trois du composer d\'IFFD '
              '(`:2707-2713`, `break;` nus) sont exactement cela');
    });
  });

  group('🔴 C5-A3 — AD-10 : une pièce jointe n\'emporte JAMAIS la conversation',
      () {
    test('un picker d\'HÔTE qui LÈVE produit un `Left`, pas une exception',
        () async {
      final ZChatAttachmentController c = ZChatAttachmentController(
        picker: _ScriptedPicker(throws: true),
      );
      addTearDown(c.dispose);
      // 🔴 Sans le `try` du contrôleur, cette ligne LÈVERAIT — et l'exception
      // remonterait dans le gestionnaire de tap de l'hôte.
      final ZResult<ZPendingAttachment?> r = await c.pick(
        ZChatAttachmentSource.gallery,
      );
      expect(r.isLeft(), isTrue);
      expect(c.lastFailure.value?.message, contains('picker exploded'),
          reason: '🔴 la cause doit être PORTÉE, pas avalée : un échec sans '
              'diagnostic est indébogable');
      expect(c.pending.value, isEmpty);
    });

    test('un uploader d\'HÔTE qui LÈVE produit un `Left`, la pièce reste en '
        'attente', () async {
      final ZChatAttachmentController c = ZChatAttachmentController(
        uploader: _ScriptedUploader(throws: true),
      );
      addTearDown(c.dispose);
      final ZPendingAttachment p = _png();
      c.add(p);
      final ZResult<ZChatAttachment> r = await c.upload(p);
      expect(r.isLeft(), isTrue);
      expect(c.pending.value, hasLength(1),
          reason: '🔴 un téléversement raté ne doit pas FAIRE DISPARAÎTRE le '
              'fichier que l\'utilisateur avait choisi');
      expect(c.uploaded.value, isEmpty);
    });

    test('aucune couture câblée ⇒ `Left` explicite, jamais de nullité levée',
        () async {
      final ZChatAttachmentController c = ZChatAttachmentController();
      addTearDown(c.dispose);
      expect((await c.pick(ZChatAttachmentSource.files)).isLeft(), isTrue);
      expect((await c.upload(_png())).isLeft(), isTrue);
    });

    test('`remove` hors bornes est IGNORÉ (forme de lex)', () {
      final ZChatAttachmentController c = ZChatAttachmentController();
      addTearDown(c.dispose);
      c.add(_png());
      c
        ..remove(-1)
        ..remove(7);
      expect(c.pending.value, hasLength(1));
      c.remove(0);
      expect(c.pending.value, isEmpty);
    });
  });

  group('🔴 C5-A4 — `ZChatAttachment` du KERNEL est CÂBLÉ, pas redéclaré', () {
    test('le téléversement produit l\'entité du kernel et l\'expose', () async {
      final _ScriptedUploader uploader = _ScriptedUploader();
      final ZChatAttachmentController c = ZChatAttachmentController(
        uploader: uploader,
      );
      addTearDown(c.dispose);
      final ZPendingAttachment p = _png(name: 'note.png');
      c.add(p);
      final ZResult<ZChatAttachment> r = await c.upload(p);

      final ZChatAttachment stored =
          r.getOrElse(() => throw StateError('attendu Right'));
      // 🔴 Le TYPE compte : c'est celui du kernel, pas un clone local.
      expect(stored, isA<ZChatAttachment>());
      expect(stored.id, 'srv-note.png');
      expect(c.uploaded.value, <ZChatAttachment>[stored]);
      expect(c.uploadedIds, <String>['srv-note.png'],
          reason: '🔴 `uploadedIds` est le SEUL point de contact avec '
              '`ZChatController.setAttachments` — sans lui, l\'hôte '
              'ré-implémenterait la jonction');
      expect(c.pending.value, isEmpty,
          reason: '🔴 une pièce téléversée quitte la file d\'attente, sans '
              'quoi elle serait envoyée deux fois');
    });

    test('la pièce téléversée est acceptée telle quelle par le CONTRÔLEUR de '
        'conversation', () async {
      // 🔴 Garde de JONCTION : les deux contrôleurs sont séparés (G-CH1 interdit
      // d'élargir la surface de `ZChatController`), et rien ne prouverait sans
      // cela qu'ils se parlent.
      final ZChatAttachmentController a = ZChatAttachmentController(
        uploader: _ScriptedUploader(),
      );
      addTearDown(a.dispose);
      final ZPendingAttachment p = _png(name: 'j.png');
      a.add(p);
      await a.upload(p);

      final ZChatController chat = buildController().controller;
      addTearDown(chat.dispose);
      chat.setAttachments(a.uploadedIds);
      expect(chat.attachmentIds.value, <String>['srv-j.png']);
      expect(chat.canSend.value, isTrue,
          reason: '🔴 une pièce jointe SEULE doit suffire à activer l\'envoi');
    });
  });

  group('🔴 C5-A5 — le client N\'EST PAS l\'autorité (antivirus / vision / '
      'quota)', () {
    test('un refus SERVEUR est relayé, pas rejoué ni requalifié', () async {
      const ZFailure verdict = ZQuotaExceededFailure('multimodal quota');
      final ZChatAttachmentController c = ZChatAttachmentController(
        uploader: _ScriptedUploader(
          result: const Left<ZFailure, ZChatAttachment>(verdict),
        ),
      );
      addTearDown(c.dispose);
      final ZPendingAttachment p = _png();
      c.add(p);
      final ZResult<ZChatAttachment> r = await c.upload(p);

      final ZChatAttachmentFailure failure =
          r.swap().getOrElse(() => throw StateError('x'))
              as ZChatAttachmentFailure;
      expect(failure.reason, ZChatAttachmentRejection.rejectedByServer,
          reason: '🔴 requalifier le verdict du serveur en `uploadFailed` '
              'ferait croire à une panne de transport là où c\'est une RÈGLE '
              'métier qui a parlé');
      expect(failure.cause, verdict,
          reason: '🔴 le verdict de l\'autorité doit arriver INTACT à l\'hôte '
              '— le socle ne le paraphrase pas');
    });

    test('aucune borne locale ne prétend remplacer un contrôle serveur', () {
      // Un PNG de 1 octet passe TOUTES les bornes locales : elles sont
      // ergonomiques, jamais un filtre de sécurité. C'est le serveur qui décide.
      final ZChatAttachmentController c = ZChatAttachmentController();
      addTearDown(c.dispose);
      expect(c.add(_png(size: 1)).isRight(), isTrue);
    });
  });

  group('🔴 C5-A6 — la BANDE de pièces jointes (AD-13)', () {
    testWidgets('aucune pièce ⇒ aucune place réservée', (
      WidgetTester tester,
    ) async {
      final ZChatAttachmentController c = ZChatAttachmentController();
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(ZChatAttachmentStrip(controller: c)));
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('cible de retrait ≥ 48 dp', (WidgetTester tester) async {
      final ZChatAttachmentController c = ZChatAttachmentController();
      addTearDown(c.dispose);
      c.add(_png(name: 'photo.png'));
      await tester.pumpWidget(harness(ZChatAttachmentStrip(controller: c)));

      final Finder target = find.byType(GestureDetector);
      expect(target, findsOneWidget);
      final Size size = tester.getSize(target);
      expect(size.height, greaterThanOrEqualTo(kZChatMinTapTarget));
      expect(size.width, greaterThanOrEqualTo(kZChatMinTapTarget));
    });

    // 🔴 La garde ci-dessus était AVEUGLE, mesuré : avec le `ConstrainedBox`
    // du bouton mis à `minHeight: 0`, elle restait VERTE — la hauteur venait
    // du parent (`height`), jamais de notre plancher. Elle ne prouvait donc
    // rien de ce qu'elle prétendait défendre.
    //
    // Ce qui protège réellement l'utilisateur est ici : une hauteur d'hôte
    // SOUS le plancher ne doit pas écraser la cible. C'est le motif
    // CR-IFFD-37 — une contrainte déclarée que le parent écrase en silence.
    testWidgets(
      '🔴 une hauteur d\'hôte SOUS le plancher n\'écrase pas la cible (AD-13)',
      (WidgetTester tester) async {
        final ZChatAttachmentController c = ZChatAttachmentController();
        addTearDown(c.dispose);
        c.add(_png(name: 'photo.png'));
        await tester.pumpWidget(
          harness(ZChatAttachmentStrip(controller: c, height: 30)),
        );

        final Size size = tester.getSize(find.byType(GestureDetector));
        // Le plancher est la SEULE raison possible : 30 < 48 a été demandé.
        expect(size.height, greaterThanOrEqualTo(kZChatMinTapTarget));
        // Borne HAUTE : sans elle, un widget qui occuperait tout l'écran
        // passerait pour conforme — le défaut mesuré à 600 dp ailleurs.
        expect(size.height, lessThanOrEqualTo(96.0));
      },
    );

    testWidgets('la hauteur demandée est honorée AU-DESSUS du plancher', (
      WidgetTester tester,
    ) async {
      final ZChatAttachmentController c = ZChatAttachmentController();
      addTearDown(c.dispose);
      c.add(_png(name: 'photo.png'));
      await tester.pumpWidget(
        harness(ZChatAttachmentStrip(controller: c, height: 80)),
      );
      // Contrôle NÉGATIF : le plancher ne doit pas écraser une demande valide.
      expect(tester.getSize(find.byType(GestureDetector)).height, 80.0);
    });

    testWidgets('RTL : la bande s\'ordonne à l\'envers, sans code miroir', (
      WidgetTester tester,
    ) async {
      final ZChatAttachmentController c = ZChatAttachmentController();
      addTearDown(c.dispose);
      c
        ..add(_png(name: 'un.png'))
        ..add(_png(name: 'deux.png'));

      await tester.pumpWidget(
        harness(
          ZChatAttachmentStrip(controller: c),
          direction: TextDirection.ltr,
        ),
      );
      final double ltrFirst = tester.getTopLeft(find.text('un.png')).dx;
      final double ltrSecond = tester.getTopLeft(find.text('deux.png')).dx;
      expect(ltrFirst, lessThan(ltrSecond));

      await tester.pumpWidget(
        harness(
          ZChatAttachmentStrip(controller: c),
          direction: TextDirection.rtl,
        ),
      );
      await tester.pump();
      final double rtlFirst = tester.getTopLeft(find.text('un.png')).dx;
      final double rtlSecond = tester.getTopLeft(find.text('deux.png')).dx;
      expect(rtlFirst, greaterThan(rtlSecond),
          reason: '🔴 en RTL la première pièce doit être à DROITE. Avec des '
              '`EdgeInsets.only(left:)` la bande resterait dans le mauvais '
              'sens — et aucune garde de source ne le prouverait sur la '
              'MISE EN PAGE RÉELLE');
    });

    testWidgets('le retrait passe par le CONTRÔLEUR et retire la bonne pièce', (
      WidgetTester tester,
    ) async {
      final ZChatAttachmentController c = ZChatAttachmentController();
      addTearDown(c.dispose);
      c
        ..add(_png(name: 'un.png'))
        ..add(_png(name: 'deux.png'));
      await tester.pumpWidget(harness(ZChatAttachmentStrip(controller: c)));

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(
        c.pending.value.map((ZPendingAttachment a) => a.fileName),
        <String>['deux.png'],
      );
    });

    testWidgets('les libellés sont RÉSOLUS, jamais codés en dur', (
      WidgetTester tester,
    ) async {
      final ZChatAttachmentController c = ZChatAttachmentController();
      addTearDown(c.dispose);
      c.add(_png(name: 'x.png'));
      await tester.pumpWidget(
        harness(
          ZChatAttachmentStrip(controller: c),
          labels: <String, String>{kZChatLabelRemoveAttachment: 'Retirer'},
        ),
      );
      expect(find.text('Retirer'), findsOneWidget,
          reason: '🔴 si le libellé injecté n\'apparaît pas, c\'est qu\'un '
              'texte en dur a pris sa place');
    });

    testWidgets('la vignette de l\'hôte est une COUTURE : `null` reste neutre',
        (WidgetTester tester) async {
      final ZChatAttachmentController c = ZChatAttachmentController();
      addTearDown(c.dispose);
      c.add(_png(name: 'x.png'));
      int calls = 0;
      await tester.pumpWidget(
        harness(
          ZChatAttachmentStrip(
            controller: c,
            thumbnailBuilder: (BuildContext context, ZPendingAttachment a) {
              calls++;
              return null;
            },
          ),
        ),
      );
      expect(calls, greaterThan(0), reason: '🔴 la couture n\'est pas consultée');
      expect(find.text('x.png'), findsOneWidget,
          reason: '🔴 `null` doit valoir « garde le rendu neutre », pas '
              '« n\'affiche rien »');
    });

    testWidgets('AUCUN décodage d\'image dans la bande (SM-1)', (
      WidgetTester tester,
    ) async {
      final ZChatAttachmentController c = ZChatAttachmentController();
      addTearDown(c.dispose);
      c.add(_png(name: 'gros.png'));
      await tester.pumpWidget(harness(ZChatAttachmentStrip(controller: c)));
      expect(find.byType(Image), findsNothing,
          reason: '🔴 décoder un bitmap de 10 Mio dans le composer, à chaque '
              'rebuild, pour une vignette de 48 dp — l\'exact opposé de SM-1');
    });
  });
}
