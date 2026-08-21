/// Gardes du calculateur de teinte lisible **remonté dans le cœur**.
///
/// Le dépôt en portait **deux** implémentations : l'originale dans
/// `zcrud_study` (CR-IFFD-64) et une copie mot à mot dans `zcrud_chat`
/// (CR-IFFD-84), faite parce qu'une arête `zcrud_chat → zcrud_study` aurait
/// violé l'invariant AD-1. Deux calculateurs de contraste finissent toujours
/// par diverger : l'algorithme vit désormais dans `zcrud_core`, atteignable
/// par tout satellite sans arête latérale.
///
/// ## Ce que ce fichier prouve
///
/// 1. **Équivalence STRICTE** — les deux implémentations supprimées sont
///    RECOPIÉES ICI (en privé, sous les noms `_study*` / `_chat*`) et
///    comparées **bit à bit** (`toARGB32()`) à celle du cœur sur une matrice
///    couvrant le plancher et ses deux côtés. C'est la garde qui **autorise**
///    la suppression : sans elle, « comportement identique » serait une
///    affirmation. Les copies sont VOLONTAIREMENT dupliquées ici — un test qui
///    appellerait le cœur pour vérifier le cœur serait tautologique.
/// 2. **Plancher** — une couleur sous le plancher est corrigée jusqu'à
///    l'atteindre ; une couleur au-dessus est rendue **inchangée**.
/// 3. **Surface de mesure documentée** — les deux chiffres qui ont circulé
///    pour `#FF9800` (`2,155` et `2,049`) sont **tous deux exacts**, sur deux
///    surfaces différentes ; la dartdoc doit dire laquelle.
/// 4. **Duplication supprimée** — un seul site d'implémentation dans tout
///    `packages/*/lib`, mesuré par un motif **structurel** (les coefficients
///    WCAG), pas par un nom de fonction qu'un doublon renommerait.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../../support/z_sources.dart';

// ── Les DEUX implémentations supprimées, recopiées mot à mot ──────────────
//
// 🔴 Ces copies sont l'ORACLE. Elles ne doivent JAMAIS être remplacées par un
// appel au cœur : la garde perdrait tout pouvoir de détection.

const int _kIterations = 24;

double _lin(double channel) {
  final double c = channel.clamp(0.0, 1.0);
  return c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _enc(double linear) {
  final double c = linear.clamp(0.0, 1.0);
  return c <= 0.0031308
      ? c * 12.92
      : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;
}

double _oracleLuminance(Color color) =>
    0.2126 * _lin(color.r) + 0.7152 * _lin(color.g) + 0.0722 * _lin(color.b);

double _oracleRatio(Color a, Color b) {
  final double la = _oracleLuminance(a);
  final double lb = _oracleLuminance(b);
  final double hi = math.max(la, lb);
  final double lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

Color _oracleShift(Color color, double t) {
  if (t == 0) return color;
  double apply(double channel) {
    final double linear = _lin(channel);
    final double shifted = t < 0 ? linear * (1 + t) : linear + (1 - linear) * t;
    return _enc(shifted);
  }

  return Color.from(
    alpha: color.a,
    red: apply(color.r),
    green: apply(color.g),
    blue: apply(color.b),
  );
}

/// Copie MOT À MOT de `zcrud_study/lib/src/presentation/z_readable_tint.dart`
/// (`zReadableTintOn`), tel que supprimé — deux dichotomies déroulées.
Color _studyReadableTintOn(
  Color base, {
  required Color surface,
  double minContrast = 3.0,
}) {
  final double floor = minContrast.clamp(1.0, 21.0);
  final Color opaqueSurface = surface.withValues(alpha: 1);
  double contrastAt(double t) =>
      _oracleRatio(_oracleShift(base, t).withValues(alpha: 1), opaqueSurface);

  if (contrastAt(0) >= floor) return base;

  double? darker;
  if (contrastAt(-1) >= floor) {
    double ok = -1;
    double ko = 0;
    for (int i = 0; i < _kIterations; i++) {
      final double mid = (ok + ko) / 2;
      if (contrastAt(mid) >= floor) {
        ok = mid;
      } else {
        ko = mid;
      }
    }
    darker = ok;
  }

  double? lighter;
  if (contrastAt(1) >= floor) {
    double ok = 1;
    double ko = 0;
    for (int i = 0; i < _kIterations; i++) {
      final double mid = (ok + ko) / 2;
      if (contrastAt(mid) >= floor) {
        ok = mid;
      } else {
        ko = mid;
      }
    }
    lighter = ok;
  }

  if (darker == null && lighter == null) {
    return contrastAt(-1) >= contrastAt(1)
        ? _oracleShift(base, -1)
        : _oracleShift(base, 1);
  }
  if (lighter == null) return _oracleShift(base, darker!);
  if (darker == null) return _oracleShift(base, lighter);

  final double reference = _oracleLuminance(base.withValues(alpha: 1));
  final Color darkCandidate = _oracleShift(base, darker);
  final Color lightCandidate = _oracleShift(base, lighter);
  final double dDark =
      (_oracleLuminance(darkCandidate.withValues(alpha: 1)) - reference).abs();
  final double dLight =
      (_oracleLuminance(lightCandidate.withValues(alpha: 1)) - reference).abs();
  return dDark <= dLight ? darkCandidate : lightCandidate;
}

/// Copie MOT À MOT de
/// `zcrud_chat/lib/src/presentation/view/z_chat_readable_tint.dart`
/// (`zChatReadableTintOn`), tel que supprimé — dichotomie factorisée.
Color _chatReadableTintOn(
  Color base, {
  required Color surface,
  double minContrast = 3.0,
}) {
  final double floor = minContrast.clamp(1.0, 21.0);
  final Color opaqueSurface = surface.withValues(alpha: 1);
  double contrastAt(double t) =>
      _oracleRatio(_oracleShift(base, t).withValues(alpha: 1), opaqueSurface);

  if (contrastAt(0) >= floor) return base;

  double? search(double edge) {
    if (contrastAt(edge) < floor) return null;
    double ok = edge;
    double ko = 0;
    for (int i = 0; i < _kIterations; i++) {
      final double mid = (ok + ko) / 2;
      if (contrastAt(mid) >= floor) {
        ok = mid;
      } else {
        ko = mid;
      }
    }
    return ok;
  }

  final double? darker = search(-1);
  final double? lighter = search(1);

  if (darker == null && lighter == null) {
    return contrastAt(-1) >= contrastAt(1)
        ? _oracleShift(base, -1)
        : _oracleShift(base, 1);
  }
  if (lighter == null) return _oracleShift(base, darker!);
  if (darker == null) return _oracleShift(base, lighter);

  final double reference = _oracleLuminance(base.withValues(alpha: 1));
  final Color darkCandidate = _oracleShift(base, darker);
  final Color lightCandidate = _oracleShift(base, lighter);
  final double dDark =
      (_oracleLuminance(darkCandidate.withValues(alpha: 1)) - reference).abs();
  final double dLight =
      (_oracleLuminance(lightCandidate.withValues(alpha: 1)) - reference).abs();
  return dDark <= dLight ? darkCandidate : lightCandidate;
}

// ── Matrice de mesure ────────────────────────────────────────────────────

/// Teintes d'entrée : les pires cas identifiés par CR-IFFD-64/84 (jaune,
/// quasi-blanc, orange legacy), un achromatique, un déjà conforme, et des
/// couleurs semi-transparentes (l'alpha doit être PRÉSERVÉ).
const List<Color> _tints = <Color>[
  Color(0xFFFFFF00), // jaune pur — le pire cas mesuré
  Color(0xFF00FF00),
  Color(0xFFFFFFFE), // quasi-blanc — l'artefact HSL
  Color(0xFFFF9800), // l'orange legacy IFFD de la carte mentale
  Color(0xFF808080), // achromatique — doit le rester
  Color(0xFF4FACFE),
  Color(0xFF667EEA), // déjà conforme en clair : INCHANGÉ attendu
  Color(0xFF1A237E),
  Color(0xFF000000),
  Color(0xFFFFFFFF),
  Color(0x80FF9800), // alpha préservé
  Color(0x40FFFF00),
];

/// Surfaces de mesure : blanc pur (la convention des tables de référence), le
/// `surface` teinté d'un thème clair Material 3 (la surface RÉELLE), un gris
/// médian (le cas où AUCUN côté ne tient un plancher élevé), du sombre.
const List<Color> _surfaces = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFFFEF7FF),
  Color(0xFF808080),
  Color(0xFF121212),
  Color(0xFF000000),
];

/// Planchers balayés : sous le plancher des composants, le plancher des
/// composants, celui du texte, et un plancher INATTEIGNABLE sur gris médian
/// (la branche « meilleure extrémité », AD-10).
const List<double> _floors = <double>[2.0, 3.0, 4.5, 7.0, 21.0];

/// Chemin (suffixe) de CE fichier — exclu du balayage anti-résidus, qui
/// chercherait sinon les noms que ce fichier cite lui-même.
const String _selfPath =
    'zcrud_core/test/presentation/theme/z_readable_tint_test.dart';

String _hex(Color c) =>
    c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();

void main() {
  group('🔴 ÉQUIVALENCE STRICTE — le cœur rend EXACTEMENT ce que rendaient les '
      'deux copies supprimées', () {
    test('bit à bit sur ${_tints.length}×${_surfaces.length}×${_floors.length} '
        'combinaisons', () {
      final List<String> divergences = <String>[];
      int compared = 0;
      for (final Color tint in _tints) {
        for (final Color surface in _surfaces) {
          for (final double floor in _floors) {
            compared++;
            final int core =
                zReadableTintOn(tint, surface: surface, minContrast: floor)
                    .toARGB32();
            final int study = _studyReadableTintOn(
              tint,
              surface: surface,
              minContrast: floor,
            ).toARGB32();
            final int chat = _chatReadableTintOn(
              tint,
              surface: surface,
              minContrast: floor,
            ).toARGB32();
            if (core != study) {
              divergences.add('study ${_hex(tint)} @${_hex(surface)} '
                  'floor=$floor : cœur=${core.toRadixString(16)} '
                  'copie=${study.toRadixString(16)}');
            }
            if (core != chat) {
              divergences.add('chat ${_hex(tint)} @${_hex(surface)} '
                  'floor=$floor : cœur=${core.toRadixString(16)} '
                  'copie=${chat.toRadixString(16)}');
            }
          }
        }
      }
      // Non-vacuité : la matrice a réellement été parcourue.
      expect(compared, _tints.length * _surfaces.length * _floors.length,
          reason: '🔴 GARDE VACUELLE : $compared combinaisons comparées');
      expect(divergences, isEmpty,
          reason: '🔴 le cœur NE REND PAS ce que rendaient les copies : la '
              'suppression de la duplication a changé le rendu. Ce lot ne doit '
              'rien changer de visible.\n${divergences.join('\n')}');
    });

    test('la matrice couvre RÉELLEMENT les deux côtés du plancher', () {
      // Contre-preuve : sans cas sous le plancher, l'équivalence ci-dessus ne
      // comparerait que des identités triviales.
      const Color white = Color(0xFFFFFFFF);
      final int under = _tints
          .where((Color c) =>
              zContrastRatio(c.withValues(alpha: 1), white) <
              kZNonTextMinContrast)
          .length;
      final int over = _tints
          .where((Color c) =>
              zContrastRatio(c.withValues(alpha: 1), white) >=
              kZNonTextMinContrast)
          .length;
      expect(under, greaterThanOrEqualTo(3),
          reason: '🔴 trop peu de teintes SOUS le plancher : vu $under');
      expect(over, greaterThanOrEqualTo(3),
          reason: '🔴 trop peu de teintes AU-DESSUS du plancher : vu $over');
    });

    test('les fonctions de mesure du cœur égalent l\'oracle', () {
      for (final Color c in _tints) {
        expect(zRelativeLuminance(c), closeTo(_oracleLuminance(c), 1e-12),
            reason: '🔴 luminance divergente sur ${_hex(c)}');
        for (final Color s in _surfaces) {
          expect(zContrastRatio(c, s), closeTo(_oracleRatio(c, s), 1e-12),
              reason: '🔴 contraste divergent ${_hex(c)} / ${_hex(s)}');
        }
      }
    });
  });

  group('🔴 PLANCHER de contraste', () {
    const Color white = Color(0xFFFFFFFF);

    test('une couleur SOUS le plancher est corrigée jusqu\'à l\'atteindre', () {
      const List<Color> under = <Color>[
        Color(0xFFFFFF00),
        Color(0xFFFF9800),
        Color(0xFFFFFFFE),
      ];
      for (final double floor in <double>[
        kZNonTextMinContrast,
        kZTextMinContrast,
      ]) {
        for (final Color c in under) {
          // TÉMOIN : la couleur brute échoue réellement — sinon la correction
          // n'est pas mesurée.
          expect(zContrastRatio(c, white), lessThan(floor),
              reason: '🔴 GARDE VACUELLE : ${_hex(c)} passe déjà $floor:1');
          final Color out =
              zReadableTintOn(c, surface: white, minContrast: floor);
          expect(out.toARGB32(), isNot(c.toARGB32()),
              reason: '🔴 ${_hex(c)} rendue BRUTE sous le plancher $floor:1');
          expect(
            zContrastRatio(out.withValues(alpha: 1), white),
            greaterThanOrEqualTo(floor),
            reason: '🔴 ${_hex(c)} → ${_hex(out)} reste sous $floor:1 '
                '(mesuré ${zContrastRatio(out.withValues(alpha: 1), white)})',
          );
        }
      }
    });

    test('une couleur AU-DESSUS du plancher est rendue INCHANGÉE (bit à bit)',
        () {
      const List<Color> over = <Color>[
        Color(0xFF667EEA),
        Color(0xFF1A237E),
        Color(0xFF000000),
      ];
      for (final Color c in over) {
        expect(zContrastRatio(c, white),
            greaterThanOrEqualTo(kZNonTextMinContrast),
            reason: '🔴 GARDE VACUELLE : ${_hex(c)} ne passe pas le plancher');
        expect(
          zReadableTintOn(c, surface: white).toARGB32(),
          c.toARGB32(),
          reason: '🔴 le choix de l\'hôte est RÉÉCRIT sans nécessité : '
              '${_hex(c)} satisfait déjà le plancher',
        );
      }
    });

    test('l\'ALPHA de la teinte est préservé', () {
      const Color semi = Color(0x80FFFF00);
      final Color out = zReadableTintOn(semi, surface: white);
      expect(out.a, closeTo(semi.a, 1e-9),
          reason: '🔴 l\'alpha de l\'hôte a été écrasé');
    });

    test('plancher INATTEIGNABLE : la meilleure extrémité, jamais un échec '
        '(AD-10)', () {
      const Color mid = Color(0xFF808080);
      final Color out =
          zReadableTintOn(const Color(0xFFFF9800), surface: mid, minContrast: 21);
      expect(zContrastRatio(out.withValues(alpha: 1), mid), greaterThan(1.0),
          reason: '🔴 la chaîne totale a rendu une couleur inerte');
    });
  });

  group('🔴 SURFACE DE MESURE — les deux chiffres sont exacts, sur deux '
      'surfaces différentes', () {
    const Color orange = Color(0xFFFF9800);
    const Color white = Color(0xFFFFFFFF);
    const Color m3LightSurface = Color(0xFFFEF7FF);

    test('#FF9800 mesure 2,155 sur BLANC PUR et 2,049 sur le `surface` M3 '
        'clair', () {
      expect(zContrastRatio(orange, white), closeTo(2.155, 0.002),
          reason: '🔴 le chiffre de référence sur BLANC a bougé');
      expect(zContrastRatio(orange, m3LightSurface), closeTo(2.049, 0.002),
          reason: '🔴 le chiffre sur le `surface` M3 clair a bougé');
      // Les deux sont sous le plancher — c'est le défaut que la CR a mesuré.
      expect(zContrastRatio(orange, white), lessThan(kZNonTextMinContrast));
      expect(zContrastRatio(orange, m3LightSurface),
          lessThan(kZNonTextMinContrast));
      // Et ils DIFFÈRENT : un chiffre de contraste n'existe pas sans surface.
      expect(
        (zContrastRatio(orange, white) -
                zContrastRatio(orange, m3LightSurface))
            .abs(),
        greaterThan(0.05),
        reason: '🔴 GARDE VACUELLE : les deux surfaces rendent le même chiffre',
      );
    });

    test('la dartdoc DIT sur quelle surface elle mesure', () {
      final String doc =
          libFile('lib/src/presentation/theme/z_readable_tint.dart')
              .readAsStringSync();
      for (final String needle in <String>[
        'blanc pur',
        '2.155',
        '2.049',
        'FEF7FF',
      ]) {
        expect(doc, contains(needle),
            reason: '🔴 la dartdoc ne dit plus sur quelle surface les chiffres '
                'de référence sont mesurés : « $needle » absent. Deux chiffres '
                'ont déjà circulé pour la même couleur.');
      }
    });
  });

  group('🔴 DUPLICATION SUPPRIMÉE — une seule implémentation dans tout '
      '`packages/*/lib`', () {
    /// Les DEUX motifs **structurels** qui repèrent un calculateur de
    /// contraste, tous deux DÉRIVÉS de la source du cœur (jamais recopiés en
    /// dur ici — un motif figé serait vert sur tout défaut) :
    ///
    /// 1. les trois **coefficients** de la luminance relative WCAG — attrape
    ///    une réimplémentation complète, même RENOMMÉE (c'était le cas :
    ///    `zChatRelativeLuminance`) ;
    /// 2. l'appel `computeLuminance` du SDK **combiné** au décalage du
    ///    rapport de contraste — attrape un calculateur qui DÉLÈGUE la
    ///    luminance au SDK et n'écrit donc aucun coefficient. Cette forme
    ///    échappait entièrement au motif 1.
    ({List<String> coefficients, RegExp sdkDelegation}) detectors() {
      // Motif VARIABLE : les coefficients sont lus dans la source du cœur,
      // jamais recopiés en dur ici. Si le cœur change de formule, la garde
      // suit — un motif figé serait vert sur tout défaut.
      final String core =
          libFile('lib/src/presentation/theme/z_readable_tint.dart')
              .readAsStringSync();
      final List<String> coefficients = RegExp(r'0\.(?:2126|7152|0722)')
          .allMatches(core)
          .map((RegExpMatch m) => m.group(0)!)
          .toSet()
          .toList()
        ..sort();
      expect(coefficients, hasLength(3),
          reason: '🔴 GARDE VACUELLE : les coefficients WCAG ne sont plus '
              'lisibles dans la source du cœur — vu $coefficients');

      // Motif 2, VARIABLE lui aussi : le décalage du rapport de contraste est
      // lu dans `zContrastRatio` (forme `(hi + 0.05) / (lo + 0.05)`), pas
      // écrit en dur. Un calculateur bâti sur `Color.computeLuminance()` ne
      // porte AUCUN coefficient — seul ce décalage le trahit.
      final RegExpMatch? offsetMatch =
          RegExp(r'\(\w+ \+ (0\.\d+)\) / \(\w+ \+ 0\.\d+\)').firstMatch(core);
      expect(offsetMatch, isNotNull,
          reason: '🔴 GARDE VACUELLE : la forme du rapport de contraste n\'est '
              'plus lisible dans la source du cœur — le motif « délégation au '
              'SDK » ne peut plus être dérivé.');
      final String offset = offsetMatch!.group(1)!;
      // Le motif 2 est une CONJONCTION : `computeLuminance` seul est légitime
      // (décider d'une brillance n'est pas mesurer un contraste) ; c'est sa
      // combinaison avec le décalage WCAG qui fait un calculateur de contraste.
      final RegExp sdkDelegation =
          RegExp('computeLuminance\\(\\)[\\s\\S]{0,400}?'
              '\\+ ${RegExp.escape(offset)}\\)');
      return (coefficients: coefficients, sdkDelegation: sdkDelegation);
    }

    /// Un fichier de `packages/*/lib` est un site d'implémentation s'il porte
    /// l'UNE des deux formes.
    bool isSite(String src, ({List<String> coefficients, RegExp sdkDelegation}) d) =>
        d.coefficients.every(src.contains) || d.sdkDelegation.hasMatch(src);

    List<String> implementationSites() {
      final Directory packages = Directory('${repoRoot().path}/packages');
      expect(packages.existsSync(), isTrue, reason: '🔴 packages/ introuvable');
      final ({List<String> coefficients, RegExp sdkDelegation}) d = detectors();

      final List<String> sites = <String>[];
      int scanned = 0;
      for (final Directory pkg in packages
          .listSync(followLinks: false)
          .whereType<Directory>()) {
        final Directory lib = Directory('${pkg.path}/lib');
        if (!lib.existsSync()) continue;
        for (final File f in lib
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((File f) => f.path.endsWith('.dart'))) {
          scanned++;
          final String src = stripLines(f.readAsLinesSync()).join('\n');
          if (isSite(src, d)) {
            sites.add(f.path
                .replaceAll(r'\', '/')
                .split('/packages/')
                .last);
          }
        }
      }
      expect(scanned, greaterThan(200),
          reason: '🔴 GARDE VACUELLE : $scanned fichiers scannés seulement');
      sites.sort();
      return sites;
    }

    test('un SEUL fichier de `packages/*/lib` porte la formule WCAG', () {
      final List<String> sites = implementationSites();
      expect(
        sites,
        <String>['zcrud_core/lib/src/presentation/theme/z_readable_tint.dart'],
        reason: '🔴 DUPLICATION. Deux calculateurs de contraste finissent '
            'toujours par diverger : l\'algorithme vit dans `zcrud_core`, '
            'atteignable par TOUT satellite sans arête latérale (AD-1). '
            'Un calculateur qui DÉLÈGUE la luminance à '
            '`Color.computeLuminance()` en est un aussi : il n\'écrit aucun '
            'coefficient, mais porte le décalage `+ 0.05` du rapport WCAG. '
            'Sites vus : $sites',
      );
    });

    test('🔴 MORDANCE du motif 2 — un calculateur DÉLÉGUANT au SDK est '
        'reconnu comme site, un usage légitime de `computeLuminance` ne '
        'l\'est pas', () {
      final ({List<String> coefficients, RegExp sdkDelegation}) d = detectors();

      // La forme exacte qui a échappé à la garde pendant trois versions :
      // aucun coefficient, luminance déléguée au SDK.
      const String delegating = '''
double _wcagContrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}''';
      expect(isSite(delegating, d), isTrue,
          reason: '🔴 GARDE INERTE : un calculateur de contraste bâti sur '
              '`Color.computeLuminance()` passe au travers — c\'est '
              'exactement l\'angle mort qui a laissé vivre un TROISIÈME '
              'calculateur.');

      // Contre-témoin : décider d'une brillance n'est pas mesurer un
      // contraste. Sans cette moitié, la garde interdirait un usage légitime.
      const String legitimate = '''
Brightness _brightnessOf(Color c) =>
    c.computeLuminance() > 0.5 ? Brightness.light : Brightness.dark;''';
      expect(isSite(legitimate, d), isFalse,
          reason: '🔴 GARDE TROP LARGE : `computeLuminance` seul est un usage '
              'légitime ; seule sa combinaison avec le décalage WCAG fait un '
              'calculateur de contraste.');

      // Et le motif 1 reste mordant, indépendamment du motif 2.
      expect(
          isSite('0.2126 * r + 0.7152 * g + 0.0722 * b', d), isTrue,
          reason: '🔴 le motif des coefficients a cessé de mordre');
    });

    test('les noms préfixés `zChat*` de la copie supprimée n\'ont pas '
        'ressuscité', () {
      final Directory packages = Directory('${repoRoot().path}/packages');
      final List<String> residues = <String>[];
      for (final Directory pkg in packages
          .listSync(followLinks: false)
          .whereType<Directory>()) {
        for (final String sub in <String>['lib', 'test']) {
          final Directory d = Directory('${pkg.path}/$sub');
          if (!d.existsSync()) continue;
          for (final File f in d
              .listSync(recursive: true, followLinks: false)
              .whereType<File>()
              .where((File f) => f.path.endsWith('.dart'))) {
            // 🔴 Ce fichier PORTE les noms recherchés (dans la liste
            // ci-dessous) : s'auto-scanner le ferait rougir en permanence.
            if (f.path.replaceAll(r'\', '/').endsWith(_selfPath)) continue;
            final String src = stripLines(f.readAsLinesSync()).join('\n');
            for (final String name in <String>[
              'zChatReadableTintOn',
              'zChatRelativeLuminance',
              'zChatContrastRatio',
              'kZChatNonTextMinContrast',
              'kZChatTextMinContrast',
            ]) {
              if (src.contains(name)) {
                residues.add('${f.path.split('/packages/').last} → $name');
              }
            }
          }
        }
      }
      expect(residues, isEmpty,
          reason: '🔴 la copie `zcrud_chat` est revenue.\n'
              '${residues.join('\n')}');
    });
  });
}
