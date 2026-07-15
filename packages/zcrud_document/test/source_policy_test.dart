@TestOn('vm')
/// Politiques de SOURCE tenues par machine (ES-8.2, D10, AC13) — **garde
/// AJOUTÉE** (NFR-S10 / R13 : retarget/ajout, jamais suppression).
///
/// ## ⚠️ Pourquoi ce fichier est SÉPARÉ et taggé `@TestOn('vm')`
///
/// Ces tests **lisent le disque** (`dart:io`) : ils tournent sur la VM. Depuis la
/// bascule Flutter d'ES-8.2 (D2/D5), `zcrud_document` **sort de la cible
/// `gate:web`** (`gate_web_determinism.dart` EXCLUT tout package `sdk: flutter`)
/// — les matrices de coercition JSON déterministe du DOMAINE (`ZAnnotationBounds`
/// `[0,1]`, `ZDocumentAnnotation.sanitizePage`, `sanitizeExtra`) ne sont **plus
/// rejouées sous `dart test -p node`**. C'est une **PERTE DE COUVERTURE DE
/// PLATEFORME** documentée (**DW-ES82-1**, jumeau DW-ES-6.1-1), **PAS** une
/// régression (les suites tournent toujours, sous VM, via `flutter test`).
///
/// ## 🔴 La pureté du DOMAINE est AJOUTÉE, jamais supprimée
///
/// Avant ES-8.2, `zcrud_document` n'avait AUCUNE garde de pureté (il était
/// pur-Dart de fait). La bascule Flutter introduit `lib/src/presentation/`
/// (autorisé à importer Flutter/`zcrud_core`) ⇒ il faut désormais **prouver par
/// machine** que le DOMAINE (`lib/src/domain/`) reste pur-Dart (aucun
/// `package:flutter`/`dart:ui`) — sinon la promesse NFR-S10 (« domaine
/// importable/pur ») tomberait silencieusement.
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // AC13(a) — DOMAINE PUR-DART : aucun import Flutter/dart:ui.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC13(a) — pureté du domaine (NFR-S10, garde AJOUTÉE)', () {
    test('⛔ lib/src/domain/ n\'importe NI package:flutter NI dart:ui', () {
      final coupables = <String>[];
      _sourcesUnder('lib/src/domain').forEach((path, src) {
        if (src.contains('package:flutter/') ||
            RegExp(r'''import\s+['"]dart:ui['"]''').hasMatch(src)) {
          coupables.add(path);
        }
      });
      expect(coupables, isEmpty,
          reason: 'NFR-S10 : le domaine reste PUR-DART, réutilisable sans '
              'Flutter. La bascule ES-8.2 ne concerne QUE lib/src/presentation/.');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC13(b) — la PRÉSENTATION est autorisée à importer Flutter/zcrud_core.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC13(b) — la présentation compose Flutter + zcrud_core', () {
    test('✅ lib/src/presentation/ existe et importe Flutter + zcrud_core', () {
      final presentation = _sourcesUnder('lib/src/presentation');
      expect(presentation, isNotEmpty,
          reason: 'ES-8.2 crée lib/src/presentation/ — si le dossier a disparu, '
              'les widgets ne sont plus livrés.');
      final joined = presentation.values.join('\n');
      expect(joined, contains('package:flutter/'));
      expect(joined, contains('package:zcrud_core/zcrud_core.dart'),
          reason: 'la présentation utilise la surface FLUTTER de zcrud_core '
              '(ZcrudScope/ZcrudTheme/label/zResolveColorKeyOrSlot).');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC13(c) — directionnel STRICT (AD-13, RTL) dans la présentation.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC13(c) — rendu directionnel (AD-13)', () {
    test('⛔ aucun EdgeInsets.only(left/right), Alignment.centerLeft/Right, '
        'Positioned(left/right), TextAlign.left/right', () {
      final coupables = <String>[];
      _sourcesUnder('lib/src/presentation').forEach((path, src) {
        final hits = <String>[
          if (RegExp(r'EdgeInsets\.only\([^)]*\b(left|right):').hasMatch(src))
            'EdgeInsets.only(left/right)',
          if (src.contains('Alignment.centerLeft') ||
              src.contains('Alignment.centerRight'))
            'Alignment.center{Left,Right}',
          if (RegExp(r'Positioned\([^)]*\b(left|right):').hasMatch(src))
            'Positioned(left/right)',
          if (src.contains('TextAlign.left') || src.contains('TextAlign.right'))
            'TextAlign.{left,right}',
        ];
        if (hits.isNotEmpty) coupables.add('$path → ${hits.join(", ")}');
      });
      expect(coupables, isEmpty,
          reason: 'AD-13 : utiliser les variantes DIRECTIONNELLES '
              '(EdgeInsetsDirectional, AlignmentDirectional, PositionedDirectional, '
              'TextAlign.start/end) — INJ R3-8.');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC13(d) — anti-hardcode COULEUR (FR-26) dans la présentation.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC13(d) — couleur INJECTÉE, jamais un littéral (FR-26)', () {
    test(
        '⛔ aucun Color(0x…)/Colors.<name>/Color.fromARGB/Color.fromRGBO dans '
        'lib/src/presentation/', () {
      final coupables = <String>[];
      _sourcesUnder('lib/src/presentation').forEach((path, src) {
        final hits = <String>[
          if (RegExp(r'Color\(0x').hasMatch(src)) 'Color(0x…)',
          if (RegExp(r'\bColors\.[a-zA-Z]').hasMatch(src)) 'Colors.<name>',
          // LOW-3 (code-review ES-8.2) : la garde sous-scannait — un littéral
          // couleur peut aussi s'écrire Color.fromARGB(…)/Color.fromRGBO(…).
          if (RegExp(r'Color\.fromARGB\(').hasMatch(src)) 'Color.fromARGB(…)',
          if (RegExp(r'Color\.fromRGBO\(').hasMatch(src)) 'Color.fromRGBO(…)',
        ];
        if (hits.isNotEmpty) coupables.add('$path → ${hits.join(", ")}');
      });
      expect(coupables, isEmpty,
          reason: 'FR-26/AD-13 : toute couleur est INJECTÉE '
              '(ZcrudScope.colorKeyResolver) ou DÉRIVÉE du ColorScheme — jamais '
              'un hex en dur (INJ R3-9).');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC13(e) — surface publique BORNÉE du barrel (aucun type Flutter/Color fuité).
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC13(e) — barrel : surface publique bornée', () {
    test('✅ la présentation est exportée via `show` (jamais un export nu)', () {
      final barrel = File('lib/zcrud_document.dart').readAsStringSync();
      final presentationExports = RegExp(
        r"export\s+'src/presentation/[^']+\.dart'([^;]*);",
      ).allMatches(barrel);
      expect(presentationExports, isNotEmpty,
          reason: 'les widgets de présentation doivent être exportés.');
      for (final m in presentationExports) {
        expect(m.group(1), contains('show'),
            reason: 'chaque export de présentation DOIT être borné par `show` '
                '(aucun symbole interne — ex. helper Color — ne fuit).');
      }
    });

    test('⛔ aucun nom de type Flutter/Color n\'est exporté par le barrel', () {
      final barrel = File('lib/zcrud_document.dart').readAsStringSync();
      final shown = <String>{};
      for (final m in RegExp(r'export\s+[^;]*show\s+([^;]+);').allMatches(barrel)) {
        for (final id in m.group(1)!.split(',')) {
          final name = id.trim();
          if (name.isNotEmpty) shown.add(name);
        }
      }
      // Aucun symbole exporté ne doit être un type Flutter concret de dessin.
      const interdits = <String>{
        'Color', 'Colors', 'Widget', 'Icon', 'IconData', 'ColorScheme',
        'EdgeInsets', 'EdgeInsetsDirectional',
      };
      expect(shown.intersection(interdits), isEmpty,
          reason: 'AC13(e) : aucun type Flutter/Color en surface publique.');
    });
  });
}

Map<String, String> _sourcesUnder(String root) {
  final dir = Directory(root);
  if (!dir.existsSync()) return <String, String>{};
  final out = <String, String>{};
  for (final f in dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    out[f.path] = _stripComments(f.readAsStringSync());
  }
  return out;
}

/// Retire commentaires de bloc et de ligne (évite les faux positifs sur les
/// exemples/dartdoc — ex. « Colors.white » cité dans un commentaire).
String _stripComments(String src) {
  final sansBlocs = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return sansBlocs
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');
}
