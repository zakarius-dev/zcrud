@TestOn('vm')
library;

// ÉGALITÉ STRICTE entre la table de dégradés par type posée par le thème
// Classic et celle du socle (`ZFlashcardCardReference.typeGradients`,
// zcrud_study).
//
// Pourquoi une garde de SOURCE et non une comparaison d'objets : le thème
// n'a pas d'arête vers `zcrud_study`, et ne doit pas en ouvrir une — même en
// `dev_dependencies`, elle entrerait dans le graphe que `graph_proof.py`
// mesure. La garde lit donc le FICHIER du socle sur disque et en extrait les
// valeurs. C'est le patron déjà employé ailleurs dans ce dépôt (une garde de
// `zcrud_study` lit la source de `zcrud_core`).
//
// 🔴 Ce qu'une table figée dans ce test ne prouverait PAS : elle comparerait le
// thème à une COPIE, et resterait verte le jour où le socle change. La source
// réelle est donc lue à chaque exécution, et l'extraction est FAILLIBLE À VOIX
// HAUTE : `zParseSocleTypeGradients` lève plutôt que de rendre une table vide,
// pour qu'un reformatage du socle fasse rougir au lieu de rendre la garde
// creuse.
//
// La morsure est prouvée DES DEUX CÔTÉS : le diff est une fonction pure de
// (table du thème, texte du socle), et les contre-preuves altèrent tantôt l'un,
// tantôt l'autre. Muter le texte en mémoire évite d'écrire dans `zcrud_study`,
// dont ce paquet n'est pas le rédacteur.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZGradientSpec, ZSignaturePaletteReference;
import 'package:zcrud_themes/zcrud_themes.dart';

import 'z_package_root.dart';

/// Chemin, relatif à la racine du monorepo, du fichier de référence du socle
/// dont la table fait foi.
const String kZSocleReferencePath =
    'packages/zcrud_study/lib/src/presentation/z_flashcard_card_reference.dart';

/// Chemin, relatif à la racine du monorepo, du fichier du socle qui déclare le
/// préfixe des clés de dégradé par type.
const String kZSocleSeamPath =
    'packages/zcrud_study/lib/src/presentation/z_default_flashcard_card.dart';

/// Les quatre clés de type attendues des deux côtés.
const Set<String> kZExpectedTypeKeys = <String>{
  'multipleChoice',
  'trueOrFalse',
  'openQuestion',
  'exercise',
};

/// Le texte du fichier de référence du socle, lu sur disque.
///
/// Lève si le fichier a été déplacé : une garde qui ne trouve plus sa source
/// doit rougir, jamais se taire.
String zReadSocleReferenceSource() {
  final File file =
      File('${zMonorepoRoot().path}/$kZSocleReferencePath');
  if (!file.existsSync()) {
    throw StateError(
      'Référence du socle introuvable : ${file.path}. La garde ne mesure '
      'plus rien — corrigez kZSocleReferencePath.',
    );
  }
  return file.readAsStringSync();
}

/// Le préfixe de clé de dégradé par type déclaré par le socle, extrait de
/// [source].
///
/// Le thème RECOPIE ce préfixe plutôt que de l'importer, pour ne pas ouvrir
/// d'arête vers le paquet d'étude ; la valeur recopiée n'a donc de sens que
/// tant qu'une garde la compare à l'originale.
String zParseSocleGradientKeyPrefix(String source) {
  final RegExpMatch? m = RegExp(
    r"const\s+String\s+kZFlashcardTypeGradientKeyPrefix\s*=\s*'([^']*)'\s*;",
  ).firstMatch(_stripComments(source));
  if (m == null) {
    throw StateError(
      'Préfixe `kZFlashcardTypeGradientKeyPrefix` introuvable dans la source '
      'du socle : la garde ne mesure plus rien.',
    );
  }
  return m.group(1)!;
}

/// Retire les commentaires de [source] : les motifs ciblent le CODE.
String _stripComments(String source) => source
    .split('\n')
    .map((String line) {
      final int i = line.indexOf('//');
      return i < 0 ? line : line.substring(0, i);
    })
    .join('\n');

/// Un `AlignmentDirectional` nommé dans la source, résolu en valeur.
Alignment? _alignment(String name) => const <String, AlignmentDirectional>{
      'AlignmentDirectional.centerStart': AlignmentDirectional.centerStart,
      'AlignmentDirectional.centerEnd': AlignmentDirectional.centerEnd,
      'AlignmentDirectional.topStart': AlignmentDirectional.topStart,
      'AlignmentDirectional.bottomEnd': AlignmentDirectional.bottomEnd,
    }[name]
        ?.resolve(TextDirection.ltr);

/// Une constante `ZGradientSpec` déclarée dans la source du socle.
final RegExp _specPattern = RegExp(
  r'static\s+const\s+ZGradientSpec\s+(\w+)\s*=\s*ZGradientSpec\(\s*'
  r'gradient:\s*LinearGradient\(\s*'
  r'begin:\s*([\w.]+)\s*,\s*'
  r'end:\s*([\w.]+)\s*,\s*'
  r'colors:\s*<Color>\[\s*Color\(\s*0x([0-9a-fA-F]{8})\s*\)\s*,\s*'
  r'Color\(\s*0x([0-9a-fA-F]{8})\s*\)\s*,?\s*\]\s*,?\s*'
  r'\)\s*,\s*'
  r'onGradient:\s*Color\(\s*0x([0-9a-fA-F]{8})\s*\)\s*,?\s*'
  r'\)\s*;',
);

/// Le corps de la table `typeGradients` du socle.
final RegExp _tablePattern = RegExp(
  r'static\s+const\s+Map<String,\s*ZGradientSpec>\s+typeGradients\s*=\s*'
  r'<String,\s*ZGradientSpec>\{([^}]*)\}\s*;',
);

/// Une entrée `'clé': constante,` de la table.
final RegExp _entryPattern = RegExp(r"'([^']+)'\s*:\s*(\w+)\s*,");

/// Extrait de [source] la table `ZFlashcardCardReference.typeGradients` du
/// socle, sous la forme exacte du jeton `ZcrudTheme.flashcardTypeGradients`.
///
/// Lève un [StateError] dès que l'extraction n'aboutit pas — table absente,
/// entrée pointant une constante inconnue, alignement non reconnu. Une garde
/// qui rendrait une table vide sur un reformatage resterait verte en ne
/// mesurant plus rien.
Map<String, ZGradientSpec> zParseSocleTypeGradients(String source) {
  final String code = _stripComments(source);

  final Map<String, ZGradientSpec> byConstant = <String, ZGradientSpec>{};
  for (final RegExpMatch m in _specPattern.allMatches(code)) {
    final Alignment? begin = _alignment(m.group(2)!);
    final Alignment? end = _alignment(m.group(3)!);
    if (begin == null || end == null) {
      throw StateError(
        'Alignement non reconnu dans ${m.group(1)} : '
        '${m.group(2)} → ${m.group(3)}.',
      );
    }
    byConstant[m.group(1)!] = ZGradientSpec(
      gradient: LinearGradient(
        begin: begin,
        end: end,
        colors: <Color>[
          Color(int.parse(m.group(4)!, radix: 16)),
          Color(int.parse(m.group(5)!, radix: 16)),
        ],
      ),
      onGradient: Color(int.parse(m.group(6)!, radix: 16)),
    );
  }

  final RegExpMatch? table = _tablePattern.firstMatch(code);
  if (table == null) {
    throw StateError(
      'Table `typeGradients` introuvable dans la source du socle : la garde '
      'ne mesure plus rien.',
    );
  }

  final Map<String, ZGradientSpec> parsed = <String, ZGradientSpec>{};
  for (final RegExpMatch e in _entryPattern.allMatches(table.group(1)!)) {
    final String key = e.group(1)!;
    final ZGradientSpec? spec = byConstant[e.group(2)!];
    if (spec == null) {
      throw StateError(
        "L'entrée '$key' pointe la constante ${e.group(2)}, que la garde n'a "
        'pas su lire.',
      );
    }
    parsed[key] = spec;
  }
  if (parsed.isEmpty) {
    throw StateError('Table `typeGradients` lue VIDE : extraction en échec.');
  }
  return parsed;
}

/// Les divergences entre [theme] et la table du socle contenue dans
/// [socleSource]. Liste vide ⇔ **égalité stricte**.
///
/// Le diff est une fonction pure de ses deux entrées, ce qui permet de prouver
/// la morsure des deux côtés sans écrire dans le paquet d'en face.
List<String> zSocleParityDiff(
  Map<String, ZGradientSpec> theme,
  String socleSource,
) {
  final Map<String, ZGradientSpec> socle = zParseSocleTypeGradients(socleSource);
  final List<String> diffs = <String>[];

  final Set<String> onlyTheme = theme.keys.toSet().difference(socle.keys.toSet());
  final Set<String> onlySocle = socle.keys.toSet().difference(theme.keys.toSet());
  for (final String k in onlyTheme.toList()..sort()) {
    diffs.add("clé '$k' posée par le thème, absente du socle");
  }
  for (final String k in onlySocle.toList()..sort()) {
    diffs.add("clé '$k' du socle, absente du thème");
  }

  for (final String k in (theme.keys.toSet()..retainAll(socle.keys)).toList()
    ..sort()) {
    final ZGradientSpec t = theme[k]!;
    final ZGradientSpec s = socle[k]!;
    final List<Color> tc = (t.gradient as LinearGradient).colors;
    final List<Color> sc = (s.gradient as LinearGradient).colors;
    if (tc.length != sc.length ||
        List<int>.generate(tc.length, (int i) => i)
            .any((int i) => tc[i].toARGB32() != sc[i].toARGB32())) {
      diffs.add("'$k' arrêts : thème $tc ≠ socle $sc");
    }
    if (t.onGradient.toARGB32() != s.onGradient.toARGB32()) {
      diffs.add("'$k' premier plan : thème ${t.onGradient} ≠ "
          'socle ${s.onGradient}');
    }
    final LinearGradient tg = t.gradient as LinearGradient;
    final LinearGradient sg = s.gradient as LinearGradient;
    if (tg.begin.resolve(TextDirection.ltr) !=
            sg.begin.resolve(TextDirection.ltr) ||
        tg.end.resolve(TextDirection.ltr) !=
            sg.end.resolve(TextDirection.ltr)) {
      diffs.add("'$k' sens : thème ${tg.begin}→${tg.end} ≠ "
          'socle ${sg.begin}→${sg.end}');
    }
  }
  return diffs;
}

void main() {
  group('dégradés par type — égalité STRICTE avec la référence du socle', () {
    test("l'extraction de la source du socle aboutit, et sur les QUATRE clés",
        () {
      // Non-vacuité : sans cette assertion, un reformatage du socle qui
      // défait les motifs rendrait la garde suivante creuse.
      final Map<String, ZGradientSpec> socle =
          zParseSocleTypeGradients(zReadSocleReferenceSource());
      expect(socle.keys.toSet(), kZExpectedTypeKeys);
    });

    test('la table posée par le thème EST la table du socle', () {
      expect(
        zSocleParityDiff(
          ZClassicCardGradientsReference.typeGradients,
          zReadSocleReferenceSource(),
        ),
        isEmpty,
        reason: 'Le thème pose la table du socle : toute divergence est un '
            'défaut, pas une variante.',
      );
    });

    test('le jeton réellement posé par le thème est cette table', () {
      // La garde précédente mesure le fichier de référence ; celle-ci mesure ce
      // que `ZcrudTheme` porte vraiment, pour qu'un câblage sur une autre table
      // ne passe pas inaperçu.
      expect(
        zSocleParityDiff(
          ZClassicTheme.forTheme(ThemeData(brightness: Brightness.light))
              .flashcardTypeGradients!,
          zReadSocleReferenceSource(),
        ),
        isEmpty,
      );
    });
  });

  group('la garde mord DU CÔTÉ DU SOCLE (source mutée en mémoire)', () {
    String source() => zReadSocleReferenceSource();

    test('un arrêt de dégradé changé', () {
      final String mute = source().replaceFirst('0xFF4FACFE', '0xFF4FACFD');
      expect(mute, isNot(source()), reason: 'mutation non appliquée');
      expect(
        zSocleParityDiff(ZClassicCardGradientsReference.typeGradients, mute),
        isNotEmpty,
      );
    });

    test('un premier plan changé', () {
      final String mute = source().replaceFirst(
        'onGradient: Color(0xFFFFFFFF)',
        'onGradient: Color(0xFF000000)',
      );
      expect(mute, isNot(source()), reason: 'mutation non appliquée');
      expect(
        zSocleParityDiff(ZClassicCardGradientsReference.typeGradients, mute),
        isNotEmpty,
      );
    });

    test('les deux entrées ré-INVERSÉES (le défaut historique exact)', () {
      // La seconde table du code de référence inverse `openQuestion` et
      // `exercise` : si le socle y basculait, la garde doit le voir.
      final String mute = source()
          .replaceFirst("'openQuestion': openQuestionGradient,",
              "'openQuestion': exerciseGradient,")
          .replaceFirst(
              "'exercise': exerciseGradient,", "'exercise': openQuestionGradient,");
      expect(mute, isNot(source()), reason: 'mutation non appliquée');
      expect(
        zSocleParityDiff(ZClassicCardGradientsReference.typeGradients, mute),
        isNotEmpty,
      );
    });

    test('une clé retirée de la table du socle', () {
      final String mute =
          source().replaceFirst("'exercise': exerciseGradient,", '');
      expect(mute, isNot(source()), reason: 'mutation non appliquée');
      expect(
        zSocleParityDiff(ZClassicCardGradientsReference.typeGradients, mute),
        isNotEmpty,
      );
    });

    test('une table illisible LÈVE, au lieu de rendre la garde creuse', () {
      final String mute = source().replaceFirst(
        'static const Map<String, ZGradientSpec> typeGradients',
        'static const Map<String, ZGradientSpec> typeGradientsRenomme',
      );
      expect(mute, isNot(source()), reason: 'mutation non appliquée');
      expect(() => zParseSocleTypeGradients(mute), throwsStateError);
    });
  });

  group('la garde mord DU CÔTÉ DU THÈME (table mutée en mémoire)', () {
    Map<String, ZGradientSpec> table() =>
        Map<String, ZGradientSpec>.from(
            ZClassicCardGradientsReference.typeGradients);

    test('un arrêt de dégradé changé', () {
      final Map<String, ZGradientSpec> mute = table();
      final LinearGradient g =
          mute['openQuestion']!.gradient as LinearGradient;
      mute['openQuestion'] = ZGradientSpec(
        gradient: LinearGradient(
          begin: g.begin,
          end: g.end,
          colors: <Color>[const Color(0xFF000001), g.colors.last],
        ),
        onGradient: mute['openQuestion']!.onGradient,
      );
      expect(zSocleParityDiff(mute, zReadSocleReferenceSource()), isNotEmpty);
    });

    test('un premier plan changé', () {
      final Map<String, ZGradientSpec> mute = table();
      mute['trueOrFalse'] = ZGradientSpec(
        gradient: mute['trueOrFalse']!.gradient,
        onGradient: const Color(0xFFFFFFFF),
      );
      expect(zSocleParityDiff(mute, zReadSocleReferenceSource()), isNotEmpty);
    });

    test('un sens de dégradé inversé', () {
      final Map<String, ZGradientSpec> mute = table();
      final LinearGradient g = mute['exercise']!.gradient as LinearGradient;
      mute['exercise'] = ZGradientSpec(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerEnd,
          end: AlignmentDirectional.centerStart,
          colors: g.colors,
        ),
        onGradient: mute['exercise']!.onGradient,
      );
      expect(zSocleParityDiff(mute, zReadSocleReferenceSource()), isNotEmpty);
    });

    test('une clé en trop, puis une clé en moins', () {
      final Map<String, ZGradientSpec> enTrop = table()
        ..['fillBlank'] = ZClassicCardGradientsReference.multipleChoice;
      expect(zSocleParityDiff(enTrop, zReadSocleReferenceSource()), isNotEmpty);

      final Map<String, ZGradientSpec> enMoins = table()..remove('exercise');
      expect(zSocleParityDiff(enMoins, zReadSocleReferenceSource()), isNotEmpty);
    });

    test('les deux entrées inversées côté thème', () {
      final Map<String, ZGradientSpec> mute = table();
      final ZGradientSpec oq = mute['openQuestion']!;
      mute['openQuestion'] = mute['exercise']!;
      mute['exercise'] = oq;
      expect(zSocleParityDiff(mute, zReadSocleReferenceSource()), isNotEmpty);
    });
  });

  group('préfixe de clé RECOPIÉ — comparé à la déclaration du socle', () {
    String seamSource() {
      final File file = File('${zMonorepoRoot().path}/$kZSocleSeamPath');
      if (!file.existsSync()) {
        throw StateError('Seam du socle introuvable : ${file.path}.');
      }
      return file.readAsStringSync();
    }

    test('le préfixe se lit bien, et il est non vide', () {
      // Non-vacuité : sans elle, un renommage côté socle rendrait la garde
      // suivante muette au lieu de la faire rougir.
      expect(zParseSocleGradientKeyPrefix(seamSource()), isNotEmpty);
    });

    test('le résolveur du thème répond aux clés que le socle FORME vraiment',
        () {
      final String prefix = zParseSocleGradientKeyPrefix(seamSource());
      final ColorScheme scheme =
          ColorScheme.fromSeed(seedColor: const Color(0xFF667EEA));
      for (final String type in kZExpectedTypeKeys) {
        expect(
          ZClassicTheme.gradients(scheme, '$prefix$type'),
          ZClassicCardGradientsReference.typeGradients[type],
          reason: 'Le préfixe recopié par le thème a divergé de celui que le '
              'socle compose : le seam ne serait plus jamais alimenté.',
        );
      }
    });

    test('un préfixe étranger reste sans réponse', () {
      // Contre-preuve : sans elle, un résolveur qui répondrait à TOUT passerait
      // le test précédent sans rien prouver du préfixe.
      final ColorScheme scheme =
          ColorScheme.fromSeed(seedColor: const Color(0xFF667EEA));
      expect(ZClassicTheme.gradients(scheme, 'autre.prefixe.openQuestion'),
          isNull);
    });
  });

  group('palette signature — ordre de la PALETTE du socle, pas des types', () {
    List<ZGradientSpec> palette(Brightness b) =>
        ZClassicTheme.forTheme(ThemeData(brightness: b)).signaturePalette!;

    test('la tête est le bandeau du thème, et lui seul', () {
      expect(palette(Brightness.light).first,
          ZClassicSurfaceReference.heroGradientLight);
      expect(palette(Brightness.dark).first,
          ZClassicSurfaceReference.heroGradientDark);
    });

    test('les quatre suivantes SONT les quatre premières du socle, en ordre',
        () {
      for (final Brightness b in Brightness.values) {
        expect(
          palette(b).skip(1).toList(),
          ZSignaturePaletteReference.gradients.take(4).toList(),
          reason: 'Réordonner la palette repeint les identités de section : '
              "l'ordre est celui de la palette du socle, jamais celui des "
              'noms de type de carte.',
        );
      }
    });

    test('la palette du socle est bien plus longue — la garde compare un '
        'PRÉFIXE, et le sait', () {
      // Sans cette assertion, `take(4)` sur une palette raccourcie à trois
      // entrées comparerait trois éléments et resterait verte.
      expect(ZSignaturePaletteReference.gradients.length, greaterThanOrEqualTo(5));
      expect(palette(Brightness.light).length, 5);
    });
  });
}
