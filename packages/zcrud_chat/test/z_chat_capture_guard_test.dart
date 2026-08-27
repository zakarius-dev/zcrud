// CHAT-10 — gardes **SOURCE** et **MESURE** de la saisie assistée.
//
// Le volet « type » de l'invariant (aucune `String` ne sort d'un
// `ZUnreviewedText`) est gardé côté kernel
// (`zcrud_chat_kernel/test/z_chat_capture_guard_test.dart`). Ici on garde le
// volet PRÉSENTATION : aucune verbe de la couche capture ne rend de texte,
// aucune écriture sauvage du composer, la cible tactile bornée des DEUX côtés,
// le RTL, et l'absence de moteur embarqué.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';
import 'support/z_chat_sources.dart';

const String _controllerFile =
    'lib/src/presentation/capture/z_chat_capture_controller.dart';
const String _barFile = 'lib/src/presentation/view/z_chat_capture_bar.dart';
const String _fieldFile =
    'lib/src/presentation/view/z_chat_capture_review_field.dart';

/// Corps de la classe [declaration] dans [file], dé-commenté.
List<String> _classBody(String file, String declaration) {
  final List<String> lines = stripped(libFile(file));
  final int start = lines.indexWhere(
    (String l) => RegExp('^$declaration\\b').hasMatch(l),
  );
  expect(start, greaterThanOrEqualTo(0),
      reason: '🔴 `$declaration` introuvable dans $file — garde VACUELLE');
  final List<String> body = <String>[];
  for (int i = start + 1; i < lines.length; i++) {
    if (RegExp(r'^\}').hasMatch(lines[i])) break;
    body.add(lines[i]);
  }
  expect(body.length, greaterThan(20),
      reason: '🔴 corps quasi vide (${body.length} lignes) : découpeur cassé');
  return body;
}

/// `(type, nom)` des membres publics déclarés au premier niveau.
List<({String type, String name})> _publicMembers(List<String> body) {
  final List<({String type, String name})> out =
      <({String type, String name})>[];
  final RegExp getter = RegExp(r'^\s{2}([\w<>?,\s.]+?)\s+get\s+(\w+)\b');
  final RegExp method = RegExp(r'^\s{2}([\w<>?,\s.]+?)\s+(\w+)\s*\(');
  final RegExp field = RegExp(r'^\s{2}final\s+([\w<>?,\s.]+?)\s+(\w+)\s*[;=]');
  for (final String l in body) {
    if (!RegExp(r'^\s{2}\S').hasMatch(l)) continue;
    final RegExpMatch? m =
        getter.firstMatch(l) ?? field.firstMatch(l) ?? method.firstMatch(l);
    if (m == null) continue;
    final String name = m.group(2)!;
    if (name.startsWith('_')) continue;
    out.add((type: m.group(1)!.trim(), name: name));
  }
  return out;
}

void main() {
  group('🔴 G10-P1 — AUCUN verbe de capture ne rend de TEXTE', () {
    test('la surface publique de `ZChatCaptureController`, en ÉGALITÉ '
        'd\'ENSEMBLE', () {
      final List<({String type, String name})> members =
          _publicMembers(_classBody(_controllerFile, 'class ZChatCaptureController'));
      expect(
        members.map((({String type, String name}) m) => m.name).toSet(),
        <String>{
          'dictation',
          'ocr',
          'normalizer',
          'review',
          'activity',
          'lastFailure',
          'hasPendingReview',
          'startDictation',
          'stopDictation',
          'scan',
          'cancelReview',
          'acceptInto',
          'dispose',
        },
        reason: '🔴 ÉGALITÉ D\'ENSEMBLE, pas « contient » (leçon G-CH1). Un '
            'membre ajouté qui rendrait le texte capturé — `String get '
            'transcript`, `ZChatDraft toDraft()`, un `sendDirectly()` de '
            'confort — rouvrirait EXACTEMENT le trou que ce lot ferme.',
      );
    });

    test('AUCUN membre public ne rend une `String` (ni nue, ni enveloppée)',
        () {
      final List<String> leaks = <String>[
        for (final ({String type, String name}) m in _publicMembers(
          _classBody(_controllerFile, 'class ZChatCaptureController'),
        ))
          if (RegExp(r'\bString\b').hasMatch(m.type)) '${m.type} ${m.name}',
      ];
      expect(
        leaks,
        isEmpty,
        reason: '🔴 le contrôleur de capture rend du texte à son appelant : '
            'ce texte peut alors partir sans relecture. La SEULE sortie est '
            '`acceptInto`, qui rend `ZResult<Unit>` et écrit dans le composer '
            '— d\'où l\'utilisateur, et lui seul, décide d\'envoyer. '
            'Fautifs : $leaks',
      );
    });

    test('AUCUN fichier de la couche capture n\'invoque `send(`', () {
      final List<String> offenders = <String>[];
      for (final String file in <String>[_controllerFile, _barFile, _fieldFile]) {
        final List<String> lines = stripped(libFile(file));
        for (int i = 0; i < lines.length; i++) {
          if (RegExp(r'\.send\s*\(').hasMatch(lines[i])) {
            offenders.add('$file:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 la capture APPELLE l\'envoi. Même « après relecture », '
              'même « juste pour le cas simple » : c\'est l\'arête que le lot '
              'existe pour ne pas avoir.\n${offenders.join('\n')}');
    });

    test('🔬 contre-preuve R3 — l\'extracteur voit un membre fautif', () {
      const List<String> witness = <String>[
        '  final ZChatCaptureReviewBuffer review = ZChatCaptureReviewBuffer();',
        '  String get transcript => review.value;',
        '  ZResult<Unit> acceptInto(ZChatController chat) {',
        '  void _syncPending() => _pending.value = true;',
      ];
      final List<({String type, String name})> got = _publicMembers(witness);
      expect(got.map((({String type, String name}) m) => m.name).toList(),
          <String>['review', 'transcript', 'acceptInto']);
      expect(
        got
            .where((({String type, String name}) m) =>
                RegExp(r'\bString\b').hasMatch(m.type))
            .map((({String type, String name}) m) => m.name),
        <String>['transcript'],
        reason: '🔴 soit la règle rate la fuite, soit elle accuse `acceptInto` '
            '— les deux la rendent inutilisable',
      );
    });
  });

  group('🔴 G10-P2 — le composer n\'est écrit QUE depuis `acceptInto`', () {
    bool composerWrite(String line) => RegExp(
      r'composer\.(text\s*=[^=]|value\s*=[^=]|clear\s*\(|selection\s*=[^=])',
    ).hasMatch(line);

    test('dans TOUT `lib/` hors du contrôleur de conversation, la seule '
        'écriture est celle du texte RELU', () {
      final List<String> sites = <String>[];
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        if (e.key.replaceAll(r'\', '/').endsWith(
            'lib/src/presentation/z_chat_controller.dart')) {
          continue; // couvert par G-CH4 (`z_chat_structure_guard_test.dart`)
        }
        for (int i = 0; i < e.value.length; i++) {
          if (composerWrite(e.value[i])) {
            sites.add('${e.key}:${i + 1}');
          }
        }
      }
      expect(sites, isNotEmpty,
          reason: '🔴 GARDE VACUELLE : plus aucune écriture — la capture '
              'n\'atteindrait plus jamais le composer');
      // Deux fichiers, et deux seulement, ont le droit d'écrire dans la
      // saisie :
      //  * le contrôleur de capture, qui CONCATÈNE le texte relu ;
      //  * le site d'écriture unique des gestes de contexte, qui ne sait que
      //    remplacer un intervalle en préservant tout ce qui est en dehors
      //    (rappel d'historique, insertion d'un candidat).
      // Tout autre fichier est un chemin de plus, et c'est ce que cette garde
      // refuse. La PRÉSERVATION de chacun des deux est assertée séparément —
      // ici et dans les gardes des gestes.
      const Set<String> autorises = <String>{
        'z_chat_capture_controller.dart',
        'z_chat_composer_edit.dart',
      };
      expect(
        sites
            .where(
              (String s) => !autorises.any((String f) => s.contains(f)),
            )
            .toList(),
        isEmpty,
        reason: '🔴 un TROISIÈME chemin écrit dans la saisie de l\'utilisateur. '
            'IFFD en avait cinq, dont un qui SUPPRIME la question tapée à '
            'l\'annulation. Sites : $sites',
      );
      expect(
        sites.where((String s) => s.contains('z_chat_composer_edit.dart')),
        hasLength(1),
        reason: '🔴 le site d\'écriture des gestes doit rester UNIQUE dans son '
            'propre fichier : deux écritures = deux comportements possibles',
      );
    });

    test('la méthode qui écrit PRÉSERVE — elle concatène, elle ne remplace pas',
        () {
      final List<String> body =
          _classBody(_controllerFile, 'class ZChatCaptureController');
      final int start = body.indexWhere(
        (String l) => RegExp(r'^\s{2}\S.*\sacceptInto\s*\(').hasMatch(l),
      );
      expect(start, greaterThanOrEqualTo(0), reason: '`acceptInto` introuvable');
      int end = body.length;
      for (int i = start + 1; i < body.length; i++) {
        if (RegExp(r'^\s{2}[A-Za-z_][\w<>?,\s.]*?\s\w+\s*\(').hasMatch(body[i])) {
          end = i;
          break;
        }
      }
      final String scope = body.sublist(start, end).join('\n');
      expect(scope, contains('composer.text'),
          reason: '🔴 GARDE VACUELLE : le bloc découpé n\'écrit rien');
      expect(scope, contains(r'$existing'),
          reason: '🔴 la saisie existante n\'est plus lue : le texte relu '
              'ÉCRASE ce que l\'utilisateur avait tapé — le défaut n°2 du lot, '
              'rejoué');
    });

    test('le chemin d\'ANNULATION ne peut pas atteindre le composer', () {
      final List<String> body =
          _classBody(_controllerFile, 'class ZChatCaptureController');
      final int start = body.indexWhere(
        (String l) => RegExp(r'^\s{2}void\s+cancelReview\s*\(').hasMatch(l),
      );
      expect(start, greaterThanOrEqualTo(0));
      int end = body.length;
      for (int i = start + 1; i < body.length; i++) {
        if (RegExp(r'^\s{2}[A-Za-z_][\w<>?,\s.]*?\s\w+\s*\(').hasMatch(body[i])) {
          end = i;
          break;
        }
      }
      final String scope = body.sublist(start, end).join('\n');
      expect(scope, contains('review.clear'),
          reason: '🔴 GARDE VACUELLE : le bloc découpé n\'est pas l\'annulation');
      expect(scope.contains('composer'), isFalse,
          reason: '🔴 l\'annulation touche le composer : c\'est LITTÉRALEMENT '
              'le défaut d\'IFFD (`:3618-3672`)');
    });
  });

  group('🔴 G10-P3 — AD-57 : aucun moteur embarqué', () {
    // 🔴 Les moteurs sont cherchés sous forme de PAQUET (`package:<nom>`), pas
    // de sous-chaîne nue. Écrite en sous-chaîne, la règle accusait
    // `ZChatAttachmentSource.camera` — une valeur d'énumération PARFAITEMENT
    // conforme de CHAT-5. Une garde qui crie au loup finit désactivée (leçon
    // E10), et c'est le seul motif de cet ajustement : le témoin ci-dessous
    // prouve qu'elle voit toujours un VRAI import.
    const List<String> engines = <String>[
      'speech_to_text',
      'google_mlkit',
      'image_picker',
      'file_picker',
      'path_provider',
      'permission_handler',
      'camera',
    ];

    test('grep NÉGATIF sur TOUT `lib/`', () {
      final List<String> offenders = <String>[];
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        for (int i = 0; i < e.value.length; i++) {
          for (final String bad in engines) {
            if (e.value[i].contains('package:$bad')) {
              offenders.add('${e.key}:${i + 1}: ${e.value[i].trim()}');
            }
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 AD-57 : l\'hôte fournit le moteur.\n'
              '${offenders.join('\n')}');
    });

    test('le pubspec n\'a gagné AUCUNE dépendance', () {
      final File pubspec = File('${packageRoot().path}/pubspec.yaml');
      final String src = pubspec.readAsStringSync();
      final int start = src.indexOf('\ndependencies:');
      final int end = src.indexOf('\ndev_dependencies:', start);
      final List<String> deps = <String>[
        for (final String l in src.substring(start, end).split('\n'))
          if (RegExp(r'^  (\w+):').hasMatch(l))
            RegExp(r'^  (\w+):').firstMatch(l)!.group(1)!,
      ];
      expect(deps.toSet(), <String>{'flutter', 'zcrud_chat_kernel', 'zcrud_core'});
    });

    test('🔬 contre-preuve — le motif voit son témoin, et ÉPARGNE la valeur '
        'd\'énumération `camera` de CHAT-5', () {
      expect(
        engines.any((String e) => '  camera,'.contains('package:$e')),
        isFalse,
        reason: '🔴 FAUX POSITIF : la règle accuse `ZChatAttachmentSource.camera`',
      );
      expect(
        engines.any((String e) =>
            "import 'package:image_picker/image_picker.dart';"
                .contains('package:$e')),
        isTrue,
        reason: '🔴 la règle ne voit plus un import RÉEL de moteur',
      );
    });
  });

  group('🔴 G10-P4 — AD-13 : la cible tactile est bornée des DEUX côtés', () {
    testWidgets('≥ 48 dp, ET pas absurdement plus — le parent ne la dilate pas',
        (WidgetTester tester) async {
      // 🔴 Le piège que cette borne HAUTE ferme : un `Align` sans facteurs prend
      // toute la place offerte. Une cible de 600 dp de haut passerait « ≥ 48 »
      // sans être une cible. On monte donc l'action dans un parent GÉNÉREUX
      // (600×600) : sans les facteurs, la mesure explose.
      await tester.pumpWidget(
        harness(
          Center(
            child: SizedBox(
              width: 600,
              height: 600,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ZChatCaptureAction(label: 'Dicter', onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      final Size size = tester.getSize(find.byType(ZChatCaptureAction));
      expect(size.height, greaterThanOrEqualTo(48.0),
          reason: '🔴 AD-13 : cible tactile trop petite');
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, lessThanOrEqualTo(96.0),
          reason: '🔴 BORNE HAUTE : la cible fait ${size.height} dp de haut. '
              'Une garde « ≥ 48 dp » satisfaite par un widget qui remplit son '
              'parent est VERTE POUR LA MAUVAISE RAISON — c\'est le défaut '
              'mesuré ailleurs dans ce dépôt (600 dp). `Align` DOIT porter '
              '`widthFactor`/`heightFactor`.');
      expect(size.width, lessThanOrEqualTo(300.0),
          reason: '🔴 BORNE HAUTE en largeur : ${size.width} dp');
    });

    test('tout `Align` de la couche capture porte SES FACTEURS', () {
      final List<String> offenders = <String>[];
      for (final String file in <String>[_barFile, _fieldFile]) {
        final List<String> lines = stripped(libFile(file));
        for (int i = 0; i < lines.length; i++) {
          if (!RegExp(r'\bAlign\(').hasMatch(lines[i])) continue;
          final String block = lines.sublist(i, (i + 12).clamp(0, lines.length))
              .join('\n');
          if (!block.contains('widthFactor') || !block.contains('heightFactor')) {
            offenders.add('$file:${i + 1}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 `Align` sans facteurs : il prendra toute la place de son '
              'parent. Sites : $offenders');
    });
  });

  group('🔴 G10-P5 — RTL : la barre et la relecture sont directionnelles', () {
    testWidgets('en `rtl`, l\'ordre visuel des actions S\'INVERSE',
        (WidgetTester tester) async {
      Future<List<double>> xs(TextDirection direction) async {
        await tester.pumpWidget(
          harness(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ZChatCaptureAction(
                  key: const ValueKey<String>('a'),
                  label: 'Dicter',
                  onTap: () {},
                ),
                ZChatCaptureAction(
                  key: const ValueKey<String>('b'),
                  label: 'Extraire',
                  onTap: () {},
                ),
              ],
            ),
            direction: direction,
          ),
        );
        return <double>[
          tester.getTopLeft(find.byKey(const ValueKey<String>('a'))).dx,
          tester.getTopLeft(find.byKey(const ValueKey<String>('b'))).dx,
        ];
      }

      final List<double> ltr = await xs(TextDirection.ltr);
      final List<double> rtl = await xs(TextDirection.rtl);
      expect(ltr[0], lessThan(ltr[1]));
      expect(rtl[0], greaterThan(rtl[1]),
          reason: '🔴 l\'ordre n\'a pas suivi la direction : la barre est à '
              'l\'envers en arabe (AD-13)');
    });

    testWidgets('la surface de relecture rend un champ ÉDITABLE, pas un texte '
        'mort', (WidgetTester tester) async {
      final ZChatController chat = buildController().controller;
      final ZChatCaptureController capture = ZChatCaptureController();
      await tester.pumpWidget(
        harness(
          ZChatCaptureReviewField(
            capture: capture,
            chat: chat,
            cursorColor: const Color(0xFF2196F3),
          ),
          direction: TextDirection.rtl,
        ),
      );
      expect(find.byType(EditableText), findsNothing,
          reason: 'rien à relire ⇒ la surface disparaît');

      capture.review.seed('نص');
      await tester.pump();
      expect(find.byType(EditableText), findsOneWidget,
          reason: '🔴 une relecture qu\'on ne peut pas CORRIGER n\'est pas une '
              'relecture — c\'est un accusé de réception');
      capture.dispose();
      chat.dispose();
    });
  });

  group('🔴 G10-P6 — les clés du lot ont TOUTES un repli lisible', () {
    test('les neuf clés CHAT-10 sont déclarées ET repliées', () {
      const List<String> keys = <String>[
        kZChatLabelAssistedInput,
        kZChatLabelDictate,
        kZChatLabelStopDictation,
        kZChatLabelListening,
        kZChatLabelScanText,
        kZChatLabelRecognizing,
        kZChatLabelReviewCapture,
        kZChatLabelAcceptCapture,
        kZChatLabelCancelCapture,
      ];
      for (final String k in keys) {
        expect(kZChatLabelKeys, contains(k), reason: 'clé non déclarée : $k');
        expect(kZChatLabelFallbacks[k], isNotNull,
            reason: '🔴 clé SANS repli : un lecteur d\'écran annoncerait `$k`');
        expect(kZChatLabelFallbacks[k], isNotEmpty);
      }
    });

    testWidgets('un hôte qui traduit ÉCRASE le repli — jamais l\'inverse',
        (WidgetTester tester) async {
      final ZChatCaptureController capture = ZChatCaptureController(
        dictation: _NoopDictation(),
      );
      await tester.pumpWidget(
        harness(
          ZChatCaptureBar(
            controller: capture,
            onDictate: () {},
            onScan: () {},
          ),
          labels: <String, String>{kZChatLabelDictate: 'Dictate'},
        ),
      );
      expect(renderedTexts(tester), contains('Dictate'));
      expect(renderedTexts(tester), isNot(contains('Dicter')));
      capture.dispose();
    });
  });
}

/// Un port de dictée inerte — juste de quoi faire apparaître l'affordance.
class _NoopDictation implements ZChatDictationPort {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Stream<ZResult<ZChatDictationEvent>> listen({String? localeId}) =>
      const Stream<ZResult<ZChatDictationEvent>>.empty();

  @override
  Future<void> stop() async {}
}
