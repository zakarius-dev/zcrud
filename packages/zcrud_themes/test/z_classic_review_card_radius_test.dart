@TestOn('vm')
library;

// LE RAYON DE LA CARTE DE RÉVISION, mesuré au RENDU et non au jeton.
//
// Un jeton peut transiter sans jamais atteindre un pixel : la garde monte donc
// la carte réelle sous le thème et lit les DEUX sites de coin qu'elle porte
// (la `Material` et l'onde de son `InkWell`). Un coin resté sur `radiusM` se
// verrait à l'écran, et se voit ici.
//
// La seconde moitié de la garde mesure la PORTÉE du jeton : elle balaie les
// `lib/` de tous les paquets et dresse la liste de ses lecteurs. C'est la
// condition qui a autorisé à le poser — le jeton n'atteint qu'une surface. Le
// jour où une seconde surface se met à le lire, cette garde rougit et
// l'arbitrage est à refaire, plutôt que de rester tacite.
//
// 🔴 Le balayage lit des sources d'autres paquets, jamais ne les écrit : ce
// paquet est un PUITS du graphe et n'ouvre aucune arête vers eux. Les
// contre-preuves mutent donc une table EN MÉMOIRE.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudScope, ZcrudTheme;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_themes/zcrud_themes.dart';

import 'z_package_root.dart';

/// Carte minimale : la garde mesure le chrome, jamais le contenu.
const ZFlashcard _card = ZFlashcard(
  question: 'q',
  answer: 'a',
  type: ZFlashcardType.openQuestion,
);

/// Monte la carte de révision sous [theme], à la luminosité [brightness].
Widget zCardHost({
  required ZcrudTheme theme,
  Brightness brightness = Brightness.light,
  Radius? radius,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  home: ZcrudScope(
    theme: theme,
    child: Scaffold(
      body: SizedBox(
        width: 300,
        child: ZFlashcardReviewCard(card: _card, radius: radius),
      ),
    ),
  ),
);

/// Le rayon réellement monté par la `Material` de la carte.
BorderRadiusGeometry? zPaintedCorner(WidgetTester tester) => tester
    .widgetList<Material>(
      find.descendant(
        of: find.byType(ZFlashcardReviewCard),
        matching: find.byType(Material),
      ),
    )
    .first
    .borderRadius;

/// Le rayon réellement monté par l'`InkWell` de la carte — le SECOND site.
BorderRadius? zInkCorner(WidgetTester tester) => tester
    .widgetList<InkWell>(
      find.descendant(
        of: find.byType(ZFlashcardReviewCard),
        matching: find.byType(InkWell),
      ),
    )
    .first
    .borderRadius;

/// Rayon attendu, sous la forme réellement montée.
BorderRadius zAll(Radius r) => BorderRadius.all(r);

/// Nom du jeton dont la garde dresse la liste des lecteurs.
const String kZRadiusToken = 'flashcardCardRadius';

/// Le fichier qui DÉCLARE le jeton — il le nomme sans le lire.
const String kZRadiusDeclarationPath =
    'packages/zcrud_core/lib/src/presentation/theme/z_theme.dart';

/// Le seul consommateur attendu du jeton.
const String kZRadiusConsumerPath =
    'packages/zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart';

/// Le contenu de chaque `.dart` des `lib/` des paquets sous [root], indexé par
/// chemin relatif à [root].
///
/// [root] est un paramètre pour que la contre-preuve rejoue ce balayeur MÊME,
/// et non une copie de sa logique. Lève sur un balayage vide : une garde qui
/// comparerait le vide au vide resterait verte en ne mesurant rien.
Map<String, String> zLibSourcesByPath({Directory? root}) {
  final Directory base = root ?? zMonorepoRoot();
  final Directory packages = Directory('${base.path}/packages');
  final Map<String, String> out = <String, String>{};
  if (packages.existsSync()) {
    for (final FileSystemEntity pkg in packages.listSync()) {
      if (pkg is! Directory) continue;
      final Directory lib = Directory('${pkg.path}/lib');
      if (!lib.existsSync()) continue;
      for (final FileSystemEntity entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (!entity.existsSync()) continue;
        final String rel = entity.path
            .replaceAll(r'\', '/')
            .substring(base.path.length + 1);
        out[rel] = entity.readAsStringSync();
      }
    }
  }
  if (out.isEmpty) {
    throw StateError(
      'Aucune source lue sous packages/*/lib : la garde ne mesure plus rien.',
    );
  }
  return out;
}

/// Le CODE de [source] : commentaires retirés, ligne à ligne.
///
/// La garde mesure des lecteurs, pas des mentions : un fichier qui nomme le
/// jeton dans une documentation ne le lit pas.
String zCodeOf(String source) => source
    .split('\n')
    .map((String line) {
      final int i = line.indexOf('//');
      return i < 0 ? line : line.substring(0, i);
    })
    .join('\n');

/// Les chemins de [sources] dont le CODE nomme [token], triés.
List<String> zFilesNaming(Map<String, String> sources, String token) =>
    (sources.entries
          .where((MapEntry<String, String> e) => zCodeOf(e.value).contains(token))
          .map((MapEntry<String, String> e) => e.key)
          .toList())
      ..sort();

/// Préfixe des fichiers de CE paquet, qui ALIMENTE le jeton sans jamais le
/// lire — un thème écrit des valeurs, il n'en consomme aucune.
const String kZOwnLibPrefix = 'packages/zcrud_themes/lib/';

/// Les fichiers de [sources] qui LISENT [token] : ceux qui le nomment en code,
/// moins sa déclaration et moins ce paquet.
///
/// C'est cette liste qui dit quelles surfaces un thème repeint en posant le
/// jeton — la seule question qui décide s'il a le droit de le poser.
List<String> zReadersOf(Map<String, String> sources, String token) =>
    zFilesNaming(sources, token)
        .where((String p) => p != kZRadiusDeclarationPath)
        .where((String p) => !p.startsWith(kZOwnLibPrefix))
        .toList();

void main() {
  group('le rayon POSÉ atteint le rendu', () {
    for (final Brightness brightness in Brightness.values) {
      testWidgets('les DEUX coins de la carte valent 20 en ${brightness.name}', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          zCardHost(
            theme: ZClassicTheme.forTheme(ThemeData(brightness: brightness)),
            brightness: brightness,
          ),
        );

        final BorderRadius attendu = zAll(
          ZClassicSurfaceReference.flashcardCardRadius,
        );
        expect(zPaintedCorner(tester), attendu);
        expect(
          zInkCorner(tester),
          attendu,
          reason:
              'un coin resté sur un autre jeton se verrait à l\'écran : les '
              'deux sites de coin de la carte doivent suivre la même valeur.',
        );
      });
    }

    testWidgets('le rayon de la carte DIFFÈRE de `radiusM` — sinon la garde '
        'mesurerait le rayon des champs', (WidgetTester tester) async {
      // Non-vacuité : si les deux valeurs coïncidaient, le test ci-dessus
      // resterait vert alors même que le jeton ne serait pas posé.
      final ZcrudTheme classic = ZClassicTheme.forTheme(ThemeData.light());
      expect(classic.flashcardCardRadius, isNotNull);
      expect(
        classic.flashcardCardRadius,
        isNot(classic.radiusM),
        reason: 'le rayon de carte et celui des champs se confondent.',
      );
      expect(classic.radiusM, ZClassicSurfaceReference.cardRadius);
    });

    testWidgets('sans le thème, la carte garde le rayon d\'aujourd\'hui', (
      WidgetTester tester,
    ) async {
      // L'inertie, mesurée au rendu : le repli du socle ne pose pas le jeton,
      // et la carte retombe sur `radiusM`.
      final ZcrudTheme fallback = ZcrudTheme.fallback(ThemeData.light());
      expect(fallback.flashcardCardRadius, isNull);

      await tester.pumpWidget(zCardHost(theme: fallback));
      expect(zPaintedCorner(tester), zAll(fallback.radiusM));
      expect(
        zPaintedCorner(tester),
        isNot(zAll(ZClassicSurfaceReference.flashcardCardRadius)),
        reason: 'sans thème, la carte rendrait déjà le rayon du thème : la '
            'garde ne mesurerait alors rien.',
      );
    });

    testWidgets('le paramètre de la carte PRIME le jeton du thème', (
      WidgetTester tester,
    ) async {
      const Radius sentinelle = Radius.circular(31);
      await tester.pumpWidget(
        zCardHost(
          theme: ZClassicTheme.forTheme(ThemeData.light()),
          radius: sentinelle,
        ),
      );
      expect(zPaintedCorner(tester), zAll(sentinelle));
      expect(zInkCorner(tester), zAll(sentinelle));
    });
  });

  group('PORTÉE du jeton — un seul lecteur, et c\'est ce qui l\'autorise', () {
    late final Map<String, String> sources = zLibSourcesByPath();

    test('la carte de révision est le SEUL lecteur du jeton', () {
      expect(
        zReadersOf(sources, kZRadiusToken),
        <String>[kZRadiusConsumerPath],
        reason:
            'Une surface de plus lit ce jeton : le poser ne l\'atteint plus '
            'seule. Remesurer avant de laisser le thème le poser.',
      );
    });

    test('le balayage voit bien les autres paquets — non-vacuité', () {
      // Sans cela, un balayage qui n'aurait lu qu'un dossier rendrait la
      // liste attendue par accident.
      expect(sources.keys.where((String p) => p.startsWith('packages/')).length,
          greaterThan(200));
      expect(sources, contains(kZRadiusDeclarationPath));
      expect(sources, contains(kZRadiusConsumerPath));
      // La déclaration nomme bien le jeton : c'est elle que l'exemption
      // retire, et non un chemin devenu inexistant.
      expect(zFilesNaming(sources, kZRadiusToken),
          contains(kZRadiusDeclarationPath));
    });

    test('une MENTION en documentation ne compte pas pour un lecteur', () {
      // Une garde qui compterait les mentions désignerait des lecteurs qui
      // n'en sont pas — et rougirait sur une simple phrase de documentation.
      final Map<String, String> mute = <String, String>{
        ...sources,
        'packages/zcrud_list/lib/src/presentation/documente.dart':
            '/// Voir [ZcrudTheme.$kZRadiusToken].\nclass A {}',
      };
      expect(zReadersOf(mute, kZRadiusToken), zReadersOf(sources, kZRadiusToken));
    });

    test('un lecteur de plus est VU (table mutée en mémoire)', () {
      final Map<String, String> mute = <String, String>{
        ...sources,
        'packages/zcrud_list/lib/src/presentation/imaginaire.dart':
            'theme.$kZRadiusToken;',
      };
      expect(
        zReadersOf(mute, kZRadiusToken),
        isNot(zReadersOf(sources, kZRadiusToken)),
      );
    });

    test('un poseur de PLUS dans ce paquet reste hors du compte', () {
      // L'exemption porte sur ce paquet, et sur lui seul : elle décrit un
      // producteur de valeurs, jamais un consommateur.
      final Map<String, String> mute = <String, String>{
        ...sources,
        '${kZOwnLibPrefix}src/themes/autre/z_autre_theme.dart':
            '$kZRadiusToken: r;',
      };
      expect(zReadersOf(mute, kZRadiusToken), zReadersOf(sources, kZRadiusToken));
      expect(
        zFilesNaming(mute, kZRadiusToken),
        isNot(zFilesNaming(sources, kZRadiusToken)),
        reason: 'le balayeur ne voit même plus le fichier ajouté : '
            'l\'exemption ne prouverait rien.',
      );
    });

    test('un balayage qui ne trouve plus rien LÈVE', () {
      // Le même balayeur, ancré sur une racine sans paquets : il doit rougir
      // plutôt que de rendre une table vide dont toute comparaison serait
      // verte.
      final Directory ailleurs = Directory.systemTemp.createTempSync('zthemes');
      addTearDown(() => ailleurs.deleteSync(recursive: true));
      expect(
        () => zLibSourcesByPath(root: ailleurs),
        throwsStateError,
      );
    });
  });
}
