/// **Montage ÉNUMÉRÉ de la PAGE** — `ZStudySessionScaffold.wired`.
///
/// ## Le défaut visé
///
/// Le montage énuméré ferme, au niveau du porteur, la classe de défaut « un
/// seam oublié en silence ». L'enveloppe de page, elle, restait au régime
/// d'avant : un hôte qui monte la page — le cas le plus courant — devait
/// renoncer à la garantie, ou renoncer à la page.
///
/// ## Ce que ces gardes mesurent
///
/// 1. **Le wiring traverse ENTIER.** L'enveloppe ne lit aucun champ du wiring :
///    elle le remet tel quel au porteur. C'est structurel, pas déclaratif — un
///    seam ajouté demain au wiring atteint la page **sans qu'une ligne y soit
///    écrite**, donc sans pouvoir y être oublié.
/// 2. **Exhaustivité de l'autre moitié.** Ce que le wiring ne porte pas (les
///    cosmétiques et les défauts non nuls du porteur) est relayé nommément :
///    la garde compare les deux sources, et rougit sur un oubli.
/// 3. **L'effet de chaque seam, à l'écran.** Les mêmes sondes que le montage du
///    porteur, rejouées à travers la page : chacune porte sa contre-preuve
///    (sans le seam, l'effet disparaît).
/// 4. **Inertie.** Le constructeur par défaut de la page est resté celui d'avant
///    le lot (dump figé), et la page énumérée rend le même arbre que lui.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudScope;
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcard;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/lotw1_seams.dart';
import '../support/lotw2_scaffold.dart';
import '../support/z_sources.dart' as zsrc;
import '../support/z_study_session_harness.dart';
// Les SONDES sont celles du montage du porteur, sans copie : une seconde
// famille de sondes prouverait la page contre elle-même, jamais contre la
// mesure déjà admise.
import 'lotw1_session_wiring_test.dart'
    show CtorParam, SeamProbe, ctorBlock, ctorParams, kProbes, wiringFields;

// ═══════════════════════════════════════════════════════════════════════════
// 1. LES SCANNERS DE SOURCE — partagés par les gardes et leurs contre-preuves
// ═══════════════════════════════════════════════════════════════════════════

String scaffoldSource() =>
    zsrc.strippedOf('lib/src/presentation/z_study_session_scaffold.dart');

String hostSource() =>
    zsrc.strippedOf('lib/src/presentation/z_study_session_host.dart');

/// La liste d'initialisation du constructeur énuméré de la page.
///
/// Lève si l'ancre a bougé : une garde qui ne trouve plus son sujet ne mesure
/// plus rien.
String wiredInitializers(String source) {
  const String head = '  const ZStudySessionScaffold.wired({';
  final int start = source.indexOf(head);
  if (start < 0) {
    throw StateError('constructeur `.wired` de la page introuvable — la garde '
        'est aveugle');
  }
  final int end = source.indexOf(';', start);
  if (end < 0) throw StateError('liste d\'initialisation non terminée');
  return source.substring(start, end + 1);
}

/// Le bloc d'arguments d'un appel, depuis [head] jusqu'à [close].
String callBlock(String source, String head, String close) {
  final int start = source.indexOf(head);
  if (start < 0) {
    throw StateError('site d\'appel introuvable : $head — la garde est '
        'aveugle');
  }
  final int end = source.indexOf(close, start + head.length);
  if (end < 0) throw StateError('fin d\'appel introuvable : $head');
  return source.substring(start + head.length, end);
}

/// Les noms d'arguments nommés d'un bloc d'appel.
Set<String> namedArgs(String block) => RegExp(r'^\s*(\w+):', multiLine: true)
    .allMatches(block)
    .map((RegExpMatch m) => m.group(1)!)
    .toSet();

/// Le bloc d'arguments de l'appel énuméré au porteur, dans la page.
String wiredCall(String source) =>
    callBlock(source, 'return ZStudySessionHost.wired(', '\n      );');

/// Les MEMBRES lus sur le montage énuméré, quelle que soit la forme de l'accès.
///
/// `wiring.x`, `_wiring?.x`, `wiring!.x` : les trois écritures d'un même
/// démontage. Le scanner rend le nom du membre pour que la garde puisse le
/// confronter à l'ensemble réel des seams — lire `hashCode` n'est pas démonter
/// un montage.
Set<String> wiringMemberReads(String source) => RegExp(r'\b_?wiring[?!]?\.(\w+)')
    .allMatches(source)
    .map((RegExpMatch m) => m.group(1)!)
    .toSet();

// ═══════════════════════════════════════════════════════════════════════════
// 2. LE MONTAGE
// ═══════════════════════════════════════════════════════════════════════════

Widget _wrap(Widget page) => MaterialApp(home: ZcrudScope(child: page));

/// Arbre RÉELLEMENT monté, nœud pour nœud.
List<String> treeDump(WidgetTester tester) => tester.allWidgets
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

/// Le dump figé sur disque AVANT le lot.
List<String> baseline(W1Scene scene) {
  final File file = File('${zsrc.packageRoot().path}/test/support/'
      'z_page_tree_before_lotw2_${scene.name}.txt');
  if (!file.existsSync()) {
    throw StateError('dump de référence introuvable : ${file.path} — la garde '
        'd\'inertie ne mesure plus rien');
  }
  return file.readAsLinesSync();
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════
  // G5a — le wiring traverse ENTIER, jamais champ par champ
  // ═════════════════════════════════════════════════════════════════════════
  group('🚚 G5a — l\'enveloppe REMET le wiring, elle ne le démonte pas', () {
    test('l\'extraction aboutit', () {
      expect(wiredInitializers(scaffoldSource()), contains('_wiring'));
      expect(wiredCall(scaffoldSource()), isNotEmpty);
    });

    test('🔴 AUCUN seam n\'est lu sur le montage, nulle part dans la page', () {
      final Set<String> seams = wiringFields(hostSource()).toSet();
      expect(
        wiringMemberReads(scaffoldSource()).intersection(seams),
        isEmpty,
        reason: '🔴 un transfert champ par champ : le seam ajouté demain au '
            'montage manquera ICI, en silence',
      );
    });

    test('le wiring est remis au porteur, EXACTEMENT une fois', () {
      expect(
        RegExp(r'^\s*wiring: wiring,\s*$', multiLine: true)
            .allMatches(wiredCall(scaffoldSource()))
            .length,
        1,
      );
    });

    test('🔴 le scanner MORD : les TROIS écritures du démontage sont vues', () {
      final Set<String> seams = wiringFields(hostSource()).toSet();
      for (final String form in <String>[
        'reviewer: wiring.reviewer,',
        'reviewer: _wiring?.reviewer ?? reviewer,',
        'reviewer: wiring!.reviewer,',
      ]) {
        final String muted =
            scaffoldSource().replaceFirst('reviewer: reviewer,', form);
        expect(muted, isNot(scaffoldSource()),
            reason: 'mutation non appliquée : $form');
        expect(wiringMemberReads(muted).intersection(seams), contains('reviewer'),
            reason: 'sans cela, la garde resterait verte sur « $form »');
      }
    });

    test('un membre HORS montage lu sur le wiring ne déclenche rien', () {
      final Set<String> seams = wiringFields(hostSource()).toSet();
      final String muted = scaffoldSource()
          .replaceFirst('return ZStudySessionHost.wired(',
              'assert(wiring.hashCode != 0);\n      return ZStudySessionHost.wired(');
      expect(wiringMemberReads(muted), contains('hashCode'));
      expect(wiringMemberReads(muted).intersection(seams), isEmpty,
          reason: 'la garde vise le DÉMONTAGE, pas toute mention du type');
    });

    test('🔴 la garde LÈVE si le constructeur énuméré disparaît', () {
      final String muted = scaffoldSource().replaceAll(
          'const ZStudySessionScaffold.wired({', 'const Autre({');
      expect(() => wiredInitializers(muted), throwsStateError);
    });

    test('🔴 `.wired` de la page n\'accepte AUCUN seam à plat', () {
      final Set<String> flat = ctorParams(ctorBlock(
        scaffoldSource(),
        '  const ZStudySessionScaffold.wired({',
      )).map((CtorParam p) => p.name).toSet();
      expect(flat.intersection(wiringFields(hostSource()).toSet()), isEmpty,
          reason: '🔴 un seam posable à plat rouvrirait une règle de fusion');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // G5b — l'AUTRE moitié : tout ce que le wiring ne porte pas est relayé
  // ═════════════════════════════════════════════════════════════════════════
  group('🧮 G5b — exhaustivité du relais énuméré, mesurée sur les DEUX sources',
      () {
    /// Les paramètres que le constructeur énuméré du PORTEUR attend.
    Set<String> hostWiredParams() => <String>{
          'wiring',
          ...ctorParams(ctorBlock(hostSource(), '  ZStudySessionHost.wired({'))
              .map((CtorParam p) => p.name),
        };

    test('l\'extraction aboutit des deux côtés', () {
      expect(hostWiredParams().length, greaterThan(15));
      expect(namedArgs(wiredCall(scaffoldSource())).length, greaterThan(15));
    });

    test('🔴 CHAQUE paramètre du porteur énuméré est relayé par la page', () {
      final Set<String> expected = hostWiredParams();
      final Set<String> passed = namedArgs(wiredCall(scaffoldSource()));
      expect(expected.difference(passed), isEmpty,
          reason: '🔴 capacités perdues EN SILENCE pour un hôte qui monte la '
              'page énumérée');
      expect(passed.difference(expected), isEmpty,
          reason: '🔴 argument relayé que le porteur n\'attend plus');
    });

    test('🔴 la garde MORD : un relais retiré est signalé', () {
      final String muted = scaffoldSource().replaceFirst(
        RegExp(r'^\s*bottomInset: bottomInset,\n', multiLine: true),
        '',
      );
      expect(muted, isNot(scaffoldSource()), reason: 'mutation non appliquée');
      expect(namedArgs(wiredCall(muted)).contains('bottomInset'), isFalse);
    });

    test('🔴 la garde LÈVE si le site d\'appel énuméré disparaît', () {
      final String muted = scaffoldSource()
          .replaceAll('return ZStudySessionHost.wired(', 'return Autre(');
      expect(() => wiredCall(muted), throwsStateError);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // G5c — l'effet de CHAQUE seam, observé à travers la PAGE
  // ═════════════════════════════════════════════════════════════════════════
  group('👁️ G5c — chaque seam du wiring atteint le rendu via la page', () {
    test('une sonde par champ du wiring — ni plus, ni moins', () {
      expect(kProbes.keys.toSet(), wiringFields(hostSource()).toSet(),
          reason: '🔴 un seam sans sonde : son passage par la page ne serait '
              'prouvé que dans la source');
    });

    Future<LotW1Seams> mount(
      WidgetTester tester,
      SeamProbe probe, {
      required Set<String> omit,
      required Set<String> optIn,
    }) async {
      useTallSurface(tester);
      final LotW1Seams s =
          LotW1Seams(scene: probe.scene, omit: omit, optIn: optIn);
      await tester.pumpWidget(
        _wrap(lotW2WiredPage(s, mode: probe.mode, cards: probe.cards)),
      );
      await tester.pumpAndSettle();
      await probe.drive(tester);
      return s;
    }

    kProbes.forEach((String seam, SeamProbe probe) {
      testWidgets('`$seam` — posé sur la page : son effet est là',
          (tester) async {
        // Le seam SONDÉ est demandé nommément (cf. `LotW1Seams.optional`).
        final LotW1Seams s = await mount(tester, probe,
            omit: probe.baseOmit, optIn: <String>{seam});
        await probe.present(tester, s);
      });

      testWidgets('`$seam` — retiré : son effet DISPARAÎT (non-vacuité)',
          (tester) async {
        final LotW1Seams s = await mount(tester, probe,
            omit: <String>{...probe.baseOmit, seam}, optIn: const <String>{});
        await probe.absent(tester, s);
      });
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Inertie — la page par défaut est intacte, la page énumérée lui est égale
  // ═════════════════════════════════════════════════════════════════════════
  group('🧊 inertie — arbre identique au dump figé AVANT le lot', () {
    test('les dumps de référence sont non vides et portent la page', () {
      for (final W1Scene scene in W1Scene.values) {
        final List<String> dump = baseline(scene);
        expect(dump, isNotEmpty);
        expect(dump, contains('ZStudySessionScaffold'),
            reason: '🔴 un dump sans enveloppe ne prouverait rien');
        expect(dump, contains('ZStudySessionHost'));
      }
    });

    for (final W1Scene scene in W1Scene.values) {
      testWidgets('${scene.name} : le constructeur PAR DÉFAUT est intact',
          (tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(_wrap(lotW2FlatPage(LotW1Seams(scene: scene))));
        await tester.pumpAndSettle();
        expect(treeDump(tester), baseline(scene),
            reason: '🔴 le lot a changé l\'arbre d\'une page montée à plat');
      });

      testWidgets('${scene.name} : `.wired` rend le MÊME arbre, nœud pour nœud',
          (tester) async {
        useTallSurface(tester);
        await tester
            .pumpWidget(_wrap(lotW2WiredPage(LotW1Seams(scene: scene))));
        await tester.pumpAndSettle();
        expect(treeDump(tester), baseline(scene),
            reason: '🔴 la page énumérée ne rend pas l\'écran de la page à '
                'plat');
      });
    }

    testWidgets('`.none()` ne pose RIEN — et le dump le montre', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        _wrap(const ZStudySessionScaffold.wired(
          wiring: ZStudySessionWiring.none(),
          title: kW2Title,
          mode: ZReviewMode.list,
          queue: <ZFlashcard>[],
        )),
      );
      await tester.pumpAndSettle();
      expect(treeDump(tester), isNot(baseline(W1Scene.socle)));
      expect(find.text('$kW1:entete'), findsNothing);
    });
  });
}
