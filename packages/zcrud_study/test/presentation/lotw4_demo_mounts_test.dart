/// **Les démonstrations du socle sont montées comme le socle le recommande.**
///
/// ## Le défaut visé
///
/// Recommander le montage énuméré tout en montrant, dans ses propres
/// démonstrations, le montage qu'il remplace, laisse la recommandation à
/// l'état de prose : un lecteur copie ce qu'il voit, pas ce qu'il lit.
///
/// ## Pourquoi la garde est NOMINATIVE, jamais globale
///
/// Un balayage de tout `test/support/` interdirait le constructeur par défaut
/// **partout** — donc aussi dans les harnais qui l'exercent délibérément :
/// comparaison d'inertie entre les deux montages, audit d'un montage à plat,
/// sondes de seam. Ces harnais doivent rester à plat : c'est ce qu'ils
/// mesurent. La garde porte donc une **liste nommée de démonstrations**, et
/// rien d'autre. Ce qui n'y est pas n'est pas jugé.
///
/// ## Ce que ces gardes mesurent
///
/// 1. **G8** — aucune des démonstrations listées ne monte une session par le
///    constructeur par défaut ; chacune existe, et chacune monte réellement une
///    session (une liste ne peut pas se vider ni se peupler de fantômes).
/// 2. **Inertie** — la démonstration énumérée rend, nœud pour nœud, l'écran du
///    montage à plat de mêmes valeurs. Écrire un montage de vingt-deux seams à
///    la main est faillible ; cette égalité stricte est ce qui l'atteste.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudScope;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/z_session_mount_demos.dart';
import '../support/z_sources.dart' as zsrc;
import '../support/z_study_session_harness.dart' show useTallSurface;

// ═══════════════════════════════════════════════════════════════════════════
// La liste NOMINATIVE — les démonstrations de montage du paquet
// ═══════════════════════════════════════════════════════════════════════════

/// Les fichiers dont le rôle est de **montrer comment on monte une session**.
///
/// Y entrer engage : le fichier doit exister, monter une session, et ne la
/// monter que par le constructeur énuméré. Un harnais qui exerce le
/// constructeur par défaut n'a rien à faire ici — il n'est pas jugé.
const List<String> zDemoMountFiles = <String>[
  'test/support/z_session_mount_demos.dart',
];

/// Les deux types dont un montage de session peut partir.
const List<String> _sessionTypes = <String>[
  'ZStudySessionHost',
  'ZStudySessionScaffold',
];

/// Les manquements de [relativePaths] (chemins relatifs à la racine du
/// paquet), un message par manquement — vide si tout est conforme.
///
/// Fonction **pure au sens des données** : elle ne fait qu'échouer par sa
/// valeur de retour, jamais par `fail`. C'est ce qui permet de la conduire sur
/// des listes de contre-preuve sans faire rougir la garde elle-même.
List<String> zDemoMountViolations(List<String> relativePaths) {
  final List<String> out = <String>[];
  for (final String rel in relativePaths) {
    final File file = File('${zsrc.packageRoot().path}/$rel');
    if (!file.existsSync()) {
      out.add('$rel : démonstration INTROUVABLE (entrée fantôme dans la liste)');
      continue;
    }
    // Source DÉPOUILLÉE : une mention en commentaire n'est pas un montage.
    final String source = zsrc.strippedText(file);
    final List<String> flat = <String>[
      for (final String type in _sessionTypes)
        if (source.contains('$type(')) type,
    ];
    if (flat.isNotEmpty) {
      out.add('$rel : montage À PLAT de ${flat.join(", ")} — une '
          'démonstration monte par `.wired`');
    }
    final bool mounts =
        _sessionTypes.any((String t) => source.contains('$t.wired('));
    if (!mounts) {
      out.add('$rel : ne monte AUCUNE session — une démonstration qui ne '
          'démontre rien n\'a pas sa place dans la liste');
    }
  }
  return out;
}

// ═══════════════════════════════════════════════════════════════════════════
// La référence de comparaison — le MÊME écran, énoncé à plat
// ═══════════════════════════════════════════════════════════════════════════
//
// Ce montage à plat vit ICI, dans la garde, et non dans le fichier de
// démonstration : les deux ne peuvent pas cohabiter sous G8, et c'est voulu.
// Il est aussi, tel quel, la contre-preuve (c) — un harnais à plat hors liste
// n'est pas jugé.

ZStudySessionHost _flatHost(
  ZDemoMountSeams seams, {
  ZReviewMode mode = ZReviewMode.spaced,
  int cards = 2,
}) =>
    ZStudySessionHost(
      mode: mode,
      queue: zDemoMountQueue(cards),
      reviewer: seams.reviewer,
      contentBuilder: seams.content,
      evaluationPort: seams.evaluationPort,
      hintPort: seams.hintPort,
      labels: const ZStudySessionLabels(exitAction: kDemoMountExitLabel),
      onSessionEnd: seams.end,
      onExit: seams.exit,
      preset: ZStudySessionPreset.classic(title: kDemoMountTitle),
      cardAccentHeight: 4,
      progressStyle: ZSessionProgressStyle.pill,
    );

ZStudySessionScaffold _flatPage(
  ZDemoMountSeams seams, {
  ZReviewMode mode = ZReviewMode.spaced,
  int cards = 2,
}) =>
    ZStudySessionScaffold(
      title: kDemoMountTitle,
      mode: mode,
      queue: zDemoMountQueue(cards),
      reviewer: seams.reviewer,
      contentBuilder: seams.content,
      evaluationPort: seams.evaluationPort,
      hintPort: seams.hintPort,
      labels: const ZStudySessionLabels(exitAction: kDemoMountExitLabel),
      onSessionEnd: seams.end,
      onExit: seams.exit,
      preset: ZStudySessionPreset.classic(title: kDemoMountTitle),
      cardAccentHeight: 4,
      progressStyle: ZSessionProgressStyle.pill,
    );

/// Enveloppe d'une PAGE — elle pose son propre `Scaffold`.
Widget _wrapPage(Widget page) => MaterialApp(home: ZcrudScope(child: page));

/// Enveloppe d'un PORTEUR nu : le `Scaffold` n'est pas décoratif — la surface
/// de saisie contient un `TextField`, qui exige un ancêtre `Material`.
Widget _wrapHost(Widget host) =>
    MaterialApp(home: ZcrudScope(child: Scaffold(body: host)));

/// Arbre RÉELLEMENT monté, nœud pour nœud.
List<String> _treeDump(WidgetTester tester) => tester.allWidgets
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

Future<List<String>> _dumpOf(
  WidgetTester tester,
  Widget wrapped,
) async {
  useTallSurface(tester);
  await tester.pumpWidget(wrapped);
  await tester.pumpAndSettle();
  return _treeDump(tester);
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════
  // G8 — les démonstrations listées montent par le constructeur ÉNUMÉRÉ
  // ═════════════════════════════════════════════════════════════════════════
  group('🧩 G8 — le socle monte ses démonstrations comme il le recommande', () {
    test('la liste n\'est pas vide (une garde sans sujet ne mesure rien)', () {
      expect(zDemoMountFiles, isNotEmpty);
    });

    test('🔴 aucune démonstration listée ne monte une session à plat', () {
      expect(zDemoMountViolations(zDemoMountFiles), isEmpty,
          reason: 'une démonstration du socle contredit la recommandation du '
              'socle');
    });

    // ── Contre-preuve (a) : une entrée fantôme rougit ──────────────────────
    test('contre-preuve (a) : un fichier listé qui n\'existe pas ⇒ ROUGE', () {
      const String ghost = 'test/support/z_demonstration_absente.dart';
      expect(File('${zsrc.packageRoot().path}/$ghost').existsSync(), isFalse,
          reason: 'la contre-preuve suppose ce fichier absent');
      expect(
        zDemoMountViolations(<String>[ghost]),
        contains(contains('INTROUVABLE')),
      );
    });

    // ── Contre-preuve (b) : une entrée inutile rougit ──────────────────────
    test('contre-preuve (b) : un fichier listé sans session ⇒ ROUGE', () {
      // Fichier RÉEL du paquet, qui n'a jamais monté de session : le harnais
      // partagé. Aucune fabrication — la contre-preuve porte sur du vrai code.
      const String noMount = 'test/support/z_study_session_harness.dart';
      expect(File('${zsrc.packageRoot().path}/$noMount').existsSync(), isTrue);
      expect(
        zDemoMountViolations(<String>[noMount]),
        contains(contains('ne monte AUCUNE session')),
      );
    });

    // ── Contre-preuve (c) : un harnais à plat HORS liste reste vert ────────
    test('contre-preuve (c) : un harnais à plat hors liste n\'est PAS jugé',
        () {
      // `lotw1_seams.dart` monte délibérément à plat : c'est la référence de
      // comparaison du constructeur de transfert. La garde le montrerait en
      // faute s'il était listé…
      const String flatHarness = 'test/support/lotw1_seams.dart';
      expect(
        zDemoMountViolations(<String>[flatHarness]),
        contains(contains('montage À PLAT')),
        reason: 'sonde cassée : ce harnais ne monte plus à plat, la '
            'contre-preuve ne prouve plus rien',
      );
      // …et il ne l'est pas. La garde réelle reste donc verte, alors même
      // qu'un montage à plat existe sur le disque, à côté.
      expect(zDemoMountFiles, isNot(contains(flatHarness)));
      expect(zDemoMountViolations(zDemoMountFiles), isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Inertie — la démonstration énumérée rend l'écran du montage à plat
  // ═════════════════════════════════════════════════════════════════════════
  group('🧊 Inertie — le montage énuméré ne change rien à l\'écran', () {
    testWidgets('l\'écran : `.wired` rend le MÊME arbre que le montage à plat',
        (WidgetTester tester) async {
      final List<String> flat =
          await _dumpOf(tester, _wrapHost(_flatHost(ZDemoMountSeams())));
      final List<String> wired = await _dumpOf(
          tester, _wrapHost(zDemoMountWiredHost(ZDemoMountSeams())));
      expect(flat, isNotEmpty, reason: 'sonde cassée : arbre vide');
      expect(wired, flat,
          reason: '🔴 la démonstration énumérée ne rend pas l\'écran du '
              'montage à plat de mêmes valeurs — un seam a été mal transcrit');
    });

    testWidgets('la page : `.wired` rend le MÊME arbre que le montage à plat',
        (WidgetTester tester) async {
      final List<String> flat =
          await _dumpOf(tester, _wrapPage(_flatPage(ZDemoMountSeams())));
      final List<String> wired = await _dumpOf(
          tester, _wrapPage(zDemoMountWiredPage(ZDemoMountSeams())));
      expect(flat, isNotEmpty, reason: 'sonde cassée : arbre vide');
      expect(wired, flat,
          reason: '🔴 la page énumérée de la démonstration ne rend pas la page '
              'à plat de mêmes valeurs');
    });

    testWidgets('les seams posés ATTEIGNENT l\'écran (jamais un décor vide)',
        (WidgetTester tester) async {
      final ZDemoMountSeams seams = ZDemoMountSeams();
      useTallSurface(tester);
      await tester.pumpWidget(_wrapPage(zDemoMountWiredPage(seams)));
      await tester.pumpAndSettle();
      // Le rendu de contenu INJECTÉ par la démonstration — sans lui, la carte
      // s'afficherait quand même, avec le rendu du socle : c'est ce que cette
      // assertion distingue.
      expect(find.textContaining(kDemoMountContentTag), findsWidgets,
          reason: 'le rendu de contenu de la démonstration n\'atteint pas la '
              'carte');
      // Le titre du preset, posé par le même wiring.
      expect(find.text(kDemoMountTitle), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
