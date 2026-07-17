/// 🎯 AC1 + AC2 (SU-4) — **le swipe NAVIGUE ; il ne note JAMAIS** (FR-SU6/AD-33).
///
/// Deux axes, tous deux nécessaires :
///  1. **COMPORTEMENT** — un swipe fait avancer l'index et n'atteint **jamais**
///     le `ZSessionReviewer` ; un tap sur `ZSrsQualityButtons`, si.
///  2. **SOURCE** — le fichier de `ZSessionCardSwiper` ne mentionne **aucun**
///     symbole de notation : l'API du type rend la note **structurellement
///     impossible** (AD-34 : le régime est une propriété du TYPE).
///
/// 🔴 **ANTI-TAUTOLOGIE — NON NÉGOCIABLE (AC2).** « L'espion n'est jamais
/// appelé » est **VIDE** si l'espion ne peut de toute façon pas l'être. Le
/// **MÊME** espion, dans le **MÊME** test, DOIT être appelé par la voie légitime
/// (bouton de qualité). Sans ce témoin positif, le test reste vert même si le
/// câblage entier a disparu — le défaut « prouver la présence au lieu de
/// l'association » (HIGH su-2 / D6 su-3).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';

import 'z_swiper_harness.dart';

List<ZSessionItem> _queue(int n) => <ZSessionItem>[
      for (var i = 0; i < n; i++)
        ZSessionItem(flashcardId: 'f$i', folderId: 'd1'),
    ];

Widget _card(BuildContext context, ZSessionItem item) => Center(
      child: Text(item.flashcardId),
    );

void main() {
  group('🎯 AC2 — COMPORTEMENT : swiper n\'est PAS noter', () {
    /// Hôte de PROD miniature : la pile et la rangée de notation sont **FRÈRES**
    /// (la rangée ne descend JAMAIS dans le `cardBuilder`), et seule la rangée
    /// est câblée sur le seam — via le moteur, comme en prod.
    Future<({SpyReviewer spy, List<int> indices})> pumpHost(
      WidgetTester tester, {
      ZSrsConfig config = const ZSrsConfig(),
    }) async {
      final spy = SpyReviewer();
      final indices = <int>[];
      final engine = ZStudySessionEngine(
        queue: _queue(3),
        reviewer: spy.call,
        config: config,
      );
      addTearDown(engine.dispose);

      await tester.pumpWidget(
        wrapApp(
          Column(
            children: <Widget>[
              // FRÈRE 1 — la PILE : navigation seule.
              Expanded(
                child: ZSessionCardSwiper(
                  queue: _queue(3),
                  cardBuilder: _card,
                  passThreshold: config.passThreshold,
                  onIndexChanged: indices.add,
                ),
              ),
              // FRÈRE 2 — la NOTATION, HORS de la pile (AD-33).
              ZSrsQualityButtons(
                scale: ZQualityScale.fromConfig(config),
                passThreshold: config.passThreshold,
                onQualitySelected: engine.grade,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (spy: spy, indices: indices);
    }

    testWidgets(
        '🔴 un swipe AVANCE l\'index (1×) et n\'atteint JAMAIS le reviewer — '
        'ET le MÊME espion répond bien au bouton de qualité (témoin positif)',
        (tester) async {
      final host = await pumpHost(tester);

      // (1) SWIPE réel sur la carte de devant.
      await tester.drag(find.text('f0'), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(host.indices, <int>[1],
          reason: 'le swipe doit émettre `onIndexChanged` EXACTEMENT une fois');
      // 🎯 L'AC : le geste n'a rien noté.
      expect(
        host.spy.count,
        0,
        reason: '🔴 FR-SU6 : le swipe a NOTÉ (${host.spy.calls}) — c\'est le '
            'geste « Tinder-like » que la story interdit : la note appartient '
            'aux ZSrsQualityButtons',
      );

      // (2) 🔴 TÉMOIN POSITIF — sans lui, (1) ne prouve RIEN.
      await tester.tap(
        find.byKey(const ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}5')),
      );
      await tester.pumpAndSettle();
      expect(
        host.spy.count,
        1,
        reason: '🔴 l\'espion ne sait PAS être appelé ⇒ le « 0 appel » du swipe '
            'est une preuve VIDE (le câblage entier pourrait avoir disparu)',
      );
      expect(host.spy.calls.single.quality, 5);

      // …et noter n'a pas non plus fait avancer la pile (les deux gestes sont
      // orthogonaux : c'est l'hôte, pas la pile, qui décide de l'avance).
      expect(host.indices, <int>[1]);
    });

    testWidgets('un swipe dans l\'AUTRE sens avance AUSSI (A2 — aucune '
        'sémantique gauche/raté, droite/réussi)', (tester) async {
      final host = await pumpHost(tester);

      await tester.drag(find.text('f0'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(host.indices, <int>[1],
          reason: 'les DEUX directions horizontales font AVANCER (A2) : cela '
              'dissout le RTL et supprime la tentation « gauche = raté »');
      expect(host.spy.count, 0);
    });
  });

  group('🎯 AC1 — SOURCE : la notation est STRUCTURELLEMENT absente du type', () {
    const swiperPath = 'lib/src/presentation/z_session_card_swiper.dart';

    /// Recolle les **déclarations** (même technique et même raison que
    /// `z_widgets_purity_test.dart` : un scan ligne-à-ligne est aveugle aux
    /// coupures de `dart format`). Les commentaires/dartdoc sont écartés : ils
    /// CITENT légitimement les motifs interdits (le dartdoc du swiper explique
    /// précisément pourquoi il ne note pas).
    List<String> declarations(String path) {
      final file = File(path);
      expect(file.existsSync(), isTrue,
          reason: 'introuvable: $path (cwd=${Directory.current.path})');
      final out = <String>[];
      final buffer = StringBuffer();
      var inBlock = false;
      for (final raw in file.readAsLinesSync()) {
        var t = raw.trim();
        if (inBlock) {
          if (t.contains('*/')) {
            inBlock = false;
            t = t.substring(t.indexOf('*/') + 2).trim();
          } else {
            continue;
          }
        }
        if (t.startsWith('/*')) {
          if (!t.contains('*/')) {
            inBlock = true;
            continue;
          }
          t = t.substring(t.indexOf('*/') + 2).trim();
        }
        if (t.startsWith('//') || t.startsWith('*')) continue;
        final slash = t.indexOf('//');
        if (slash >= 0) t = t.substring(0, slash).trim();
        if (t.isEmpty) continue;
        buffer.write(t);
        if (t.endsWith(';') || t.endsWith('{') || t.endsWith('}')) {
          out.add(buffer.toString());
          buffer.clear();
        }
      }
      if (buffer.isNotEmpty) out.add(buffer.toString());
      return out;
    }

    test(
        '🔴 le fichier du swiper ne mentionne AUCUN symbole de notation '
        '(`quality`, `reviewCard`, `ZSessionReviewer`, `ZSrsScheduler`, '
        '`apply(`, `grade(`)', () {
      final decls = declarations(swiperPath);
      // Contre-preuve R12 : le scan doit réellement voir du code.
      expect(decls, isNotEmpty, reason: 'aucune déclaration scannée');

      // ⚠️ `passThreshold` est LÉGITIME (frontière réussite/lapse relayée à
      // l'indicateur de progression pour COLORER les points) — il n'écrit rien.
      // On bannit donc les symboles de NOTATION, pas le vocabulaire SRS entier.
      const banned = <String>[
        'quality',
        'reviewcard',
        'zsessionreviewer',
        'zsrsscheduler',
        'zsm2scheduler',
        'zrepetitionstore',
        '.apply(',
        'grade(',
      ];
      final violations = <String>[];
      for (final decl in decls) {
        // 🔴 **INSENSIBLE À LA CASSE — trou RÉEL de garde, mesuré et fermé.**
        // Le premier jet comparait `decl.contains('quality')` en casse exacte.
        // Or l'injection prescrite (R3-I1) ajoute `onQualitySelected` — qui
        // contient `Quality`, **pas** `quality`. La garde est donc restée
        // **VERTE sur le défaut EXACT qu'elle existe pour attraper** (mesuré :
        // « All tests passed » avec le paramètre de notation câblé sur
        // `onSwipe`). C'est précisément le scénario que su-4 doit interdire :
        // un swipe qui note, sous une suite verte.
        //
        // 🔒 Les tokens LÉGITIMES sont retirés AVANT le test : `qualityOf` /
        // `ZSessionQualityAtIndex` sont les seams de **LECTURE** de
        // l'indicateur (« quelle note a déjà reçu la carte i ? ») — ils
        // relisent, ils ne notent pas. Les retirer un par un (plutôt que de
        // sortir `quality` de la liste) garde le scan capable de voir un vrai
        // `onQualitySelected`.
        final cleaned = decl
            .toLowerCase()
            .replaceAll('qualityof', '')
            .replaceAll('zsessionqualityatindex', '');
        for (final b in banned) {
          if (cleaned.contains(b)) violations.add('$b :: $decl');
        }
      }
      expect(
        violations,
        isEmpty,
        reason: '🔴 AC1/AD-34 : un symbole de notation est apparu dans '
            '`ZSessionCardSwiper` — la notation doit y être STRUCTURELLEMENT '
            'impossible :\n${violations.join('\n')}',
      );
    });

    test('🔬 contre-preuve R12 — le scanner SAIT rougir (D6)', () {
      // On exerce le VRAI `declarations` sur un VRAI fichier : jamais une
      // ré-implémentation (qui testerait sa propre copie).
      final tmp = Directory.systemTemp.createTempSync('z_swipe_grade_probe');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final f = File('${tmp.path}/probe.dart')
        ..writeAsStringSync('final x = onSwipe(\n  quality: 5,\n);');
      expect(
        declarations(f.path).any((d) => d.contains('quality')),
        isTrue,
        reason: 'sans cette contre-preuve, la garde ci-dessus pourrait être '
            'verte pour de mauvaises raisons',
      );

      // 🔴 LE TROU RÉEL, rejoué : l'injection R3-I1 **VERBATIM**. Le motif
      // `onQualitySelected` ne contient PAS `quality` en casse exacte — la
      // garde d'origine y était structurellement aveugle (mesuré).
      final defect = File('${tmp.path}/defect.dart')
        ..writeAsStringSync(
          'class W {\n'
          '  final ValueChanged<int>? onQualitySelected;\n'
          '  void _handleSwipe(int i) {\n'
          '    widget.onQualitySelected?.call(5);\n'
          '  }\n'
          '}\n',
        );
      final defectDecls = declarations(defect.path);
      expect(
        defectDecls.any((d) => d.contains('quality')),
        isFalse,
        reason: '🔴 aucune déclaration ne porte `quality` en casse exacte ⇒ un '
            'scan sensible à la casse est STRUCTURELLEMENT aveugle au défaut '
            'que R3-I1 injecte (mesuré : la garde restait VERTE)',
      );
      expect(
        defectDecls.any((d) => d.toLowerCase().contains('quality')),
        isTrue,
        reason: 'le scan insensible à la casse, lui, le voit',
      );
      // …et un COMMENTAIRE citant le motif n'est PAS une violation (sans quoi le
      // dartdoc du swiper — qui explique la règle — se dénoncerait lui-même).
      final c = File('${tmp.path}/comment.dart')
        ..writeAsStringSync('// jamais de quality ici\nfinal x = 1;');
      expect(declarations(c.path).any((d) => d.contains('quality')), isFalse);
    });
  });
}
