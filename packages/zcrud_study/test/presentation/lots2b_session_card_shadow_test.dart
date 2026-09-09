/// **Teinte de l'ombre de la carte de session** — une teinte PAR TYPE, jamais
/// une teinte unique.
///
/// ## Le défaut visé
///
/// `ZFlashcardReviewCard` sait porter une ombre teintée, mais sa teinte n'a
/// que deux canaux : un paramètre d'instance et **un** jeton de thème. Or un
/// thème ne porte qu'une valeur : il ne peut pas décrire quatre teintes, une
/// par type de question. La référence visuelle, elle, dérive la teinte du
/// **dégradé du type** de la carte — donc une teinte différente par type sur
/// le même écran. Sans un maillon par carte, cette forme était inatteignable
/// autrement qu'en remplaçant la carte entière.
///
/// ## Ce que ces gardes mesurent — et ce qu'elles refusent de mesurer
///
/// 🔴 Lire `tester.widget<ZFlashcardReviewCard>(…).shadowColor` resterait vert
/// si la carte cessait de peindre l'ombre : ce serait mesurer le **passage**
/// du paramètre, pas son **effet**. Chaque garde lit donc la couleur
/// réellement remise au moteur de rendu, sur la `BoxDecoration` du
/// `DecoratedBox` que la carte monte sous sa clé publique. Aucune
/// rastérisation : `toImage()` pend sous ce harnais.
///
/// 🔴 La comparaison porte sur les **canaux RVB** (`toARGB32()` masqué), et
/// jamais sur la couleur entière : la carte réapplique elle-même l'opacité de
/// son ombre de référence sur la teinte reçue. Comparer les 32 bits mesurerait
/// donc l'opacité de la carte amont, pas la teinte que ce paquet relaie — une
/// garde qui rougirait au moindre ajustement d'opacité en amont, et qui ne
/// dirait rien de la teinte.
///
/// ## Inertie ABSOLUE
///
/// Sans preset, aucune boîte d'ombre n'existe dans l'arbre : la clé publique
/// de l'ombre est **absente**, pas seulement transparente.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZGradientSpec, ZcrudScope, ZcrudTheme;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, ZFlashcardReviewCard, ZFlashcardType;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/z_sources.dart' as zsrc;
import '../support/z_study_session_harness.dart';

/// Têtes de dégradé — arbitraires, DISTINCTES entre elles et de tout rôle du
/// schéma, pour qu'aucune égalité ne puisse être vraie par coïncidence.
const Color kOpenHead = Color(0xFF1B7F4C);
const Color kOpenTail = Color(0xFF2AA06A);
const Color kExerciseHead = Color(0xFFB3421E);
const Color kExerciseTail = Color(0xFFD9673F);

/// Teinte demandée explicitement par le chrome — hors de tout dégradé.
const Color kExplicitShadow = Color(0xFF00A1FF);

/// Teinte portée par le jeton de thème — hors de tout dégradé.
const Color kTokenShadow = Color(0xFF7F007F);

ZGradientSpec _spec(Color a, Color b) => ZGradientSpec(
      gradient: LinearGradient(colors: <Color>[a, b]),
      onGradient: const Color(0xFF000000),
    );

final ZGradientSpec kOpenSpec = _spec(kOpenHead, kOpenTail);
final ZGradientSpec kExerciseSpec = _spec(kExerciseHead, kExerciseTail);

/// Résolveur d'hôte : répond aux DEUX clés de type, et à rien d'autre.
ZGradientSpec? _resolver(ColorScheme scheme, String key) => switch (key) {
      'flashcard.type.openQuestion' => kOpenSpec,
      'flashcard.type.exercise' => kExerciseSpec,
      _ => null,
    };

/// Une carte du type demandé, sinon identique à celles du harnais.
ZFlashcard _typed(ZFlashcardType type) => ZFlashcard(
      id: 'c-${type.name}',
      folderId: kHarnessFolderId,
      type: type,
      question: 'Question ${type.name}.',
      answer: 'réponse ${type.name}',
    );

/// `ThemeData` clair dont l'extension est explicite : aucun jeton `cardShadow*`
/// n'y est posé, sans quoi la carte basculerait sur son canal « ombre entière »
/// et le paramètre de teinte ne serait PLUS lu (chaîne amont).
ThemeData _theme({ZcrudTheme Function(ZcrudTheme base)? tune}) {
  final ThemeData base = ThemeData(colorScheme: const ColorScheme.light());
  final ZcrudTheme fallback = ZcrudTheme.fallback(base);
  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[
      tune == null ? fallback : tune(fallback),
    ],
  );
}

Widget _wrap(
  Widget child, {
  bool withResolver = false,
  ThemeData? theme,
}) =>
    MaterialApp(
      theme: theme ?? _theme(),
      home: Scaffold(
        body: withResolver
            ? ZcrudScope(gradientResolver: _resolver, child: child)
            : child,
      ),
    );

Widget _session({
  required ZFlashcardType type,
  ZStudySessionPreset? preset,
}) =>
    ZStudySessionHost(
      mode: ZReviewMode.list,
      queue: <ZFlashcard>[_typed(type)],
      preset: preset,
    );

/// Les canaux RVB seuls — l'opacité appartient à la carte amont, pas au relais
/// mesuré ici.
int _rgb(Color c) => c.toARGB32() & 0x00FFFFFF;

/// La couleur RÉELLEMENT remise au moteur de rendu pour l'ombre de la carte.
///
/// La présence de la boîte est ASSERTÉE avant sa lecture : sans cela, une
/// régression qui supprime l'ombre ferait échouer la garde par une exception
/// de lecture plutôt que par son assertion, et le message ne dirait pas ce qui
/// a été perdu.
Color _paintedShadow(WidgetTester tester) {
  expect(find.byKey(ZFlashcardReviewCard.shadowKey), findsWidgets,
      reason: '🔴 aucune boîte d\'ombre dans l\'arbre : la teinte demandée '
          'n\'atteint pas la carte');
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.byKey(ZFlashcardReviewCard.shadowKey).first,
  );
  final List<BoxShadow>? shadows = (box.decoration as BoxDecoration).boxShadow;
  expect(shadows, isNotNull,
      reason: '🔴 la boîte d\'ombre est montée SANS ombre : la garde ne '
          'mesurerait rien');
  return shadows!.single.color;
}

/// L'opacité réellement peinte — une ombre totalement transparente satisferait
/// une comparaison RVB sans rien peindre.
double _paintedAlpha(WidgetTester tester) => _paintedShadow(tester).a;

/// Les trois motifs qui SIGNENT une réécriture de la chaîne de résolution du
/// dégradé de type — les maillons eux-mêmes, jamais leur résultat.
///
/// Ils sont nommés par leur forme de CODE : `zResolveGradient(` (une
/// soumission directe au seam), le jeton par type, et la composition de la clé
/// préfixée. Un fichier de `preset/` qui en porte un a rouvert une seconde
/// voie parallèle à `zResolveFlashcardTypeGradient`.
const Map<String, String> kZChainRewriteMotifs = <String, String>{
  'zResolveGradient(': 'soumission directe au seam de dégradé',
  'flashcardTypeGradients': 'lecture directe du jeton de dégradés par type',
  'kZFlashcardReviewTypeGradientKeyPrefix':
      'composition directe de la clé préfixée',
};

/// Les réécritures de chaîne trouvées dans [sources] (chemin → source
/// DÉPOUILLÉE), une entrée par (fichier, motif). Liste vide ⇔ un seul canal.
///
/// Fonction PURE de son entrée : la contre-preuve lui soumet un fichier
/// synthétique et exerce ainsi le détecteur réel, jamais une copie.
List<String> zChainRewritesIn(Map<String, String> sources) {
  final List<String> hits = <String>[];
  for (final MapEntry<String, String> e in sources.entries) {
    for (final MapEntry<String, String> m in kZChainRewriteMotifs.entries) {
      if (e.value.contains(m.key)) hits.add('${e.key} → ${m.value}');
    }
  }
  hits.sort();
  return hits;
}

/// Les sources DÉPOUILLÉES de `lib/src/presentation/preset/`, indexées par
/// chemin relatif au package.
Map<String, String> _presetSources() {
  const String dir = 'lib/src/presentation/preset';
  final Directory directory = Directory('${zsrc.packageRoot().path}/$dir');
  expect(directory.existsSync(), isTrue,
      reason: 'répertoire `preset/` introuvable : la garde ne mesure rien');
  return <String, String>{
    for (final FileSystemEntity f in directory.listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart'))
        '$dir/${f.uri.pathSegments.last}': zsrc.strippedText(f),
  };
}

void main() {
  group('🌑 `.classic` — l\'ombre suit le TYPE de la carte', () {
    testWidgets('question ouverte : la teinte est la TÊTE de son dégradé',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        _session(
          type: ZFlashcardType.openQuestion,
          preset: ZStudySessionPreset.classic(),
        ),
        withResolver: true,
      ));
      await tester.pumpAndSettle();

      expect(_rgb(_paintedShadow(tester)), _rgb(kOpenHead),
          reason: '🔴 la teinte peinte n\'est pas la première couleur du '
              'dégradé résolu pour ce type');
      expect(_paintedAlpha(tester), greaterThan(0),
          reason: '🔴 une ombre totalement transparente rendrait l\'égalité '
              'RVB ci-dessus vraie sans rien peindre');
    });

    testWidgets('exercice : la teinte est la TÊTE de SON dégradé, différente',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        _session(
          type: ZFlashcardType.exercise,
          preset: ZStudySessionPreset.classic(),
        ),
        withResolver: true,
      ));
      await tester.pumpAndSettle();

      expect(_rgb(_paintedShadow(tester)), _rgb(kExerciseHead));
      // Non-vacuité : les deux types ne peuvent pas rendre la même teinte.
      expect(_rgb(kExerciseHead), isNot(_rgb(kOpenHead)));
    });

    testWidgets('la TÊTE, pas la queue : la seconde couleur ne peint jamais',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        _session(
          type: ZFlashcardType.openQuestion,
          preset: ZStudySessionPreset.classic(),
        ),
        withResolver: true,
      ));
      await tester.pumpAndSettle();
      expect(_rgb(_paintedShadow(tester)), isNot(_rgb(kOpenTail)));
    });

    testWidgets('le JETON de dégradés par type sert aussi de source — le seam '
        'n\'est pas le seul maillon', (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        _session(
          type: ZFlashcardType.openQuestion,
          preset: ZStudySessionPreset.classic(),
        ),
        theme: _theme(
          tune: (ZcrudTheme base) => base.copyWith(
            flashcardTypeGradients: <String, ZGradientSpec>{
              'openQuestion': kOpenSpec,
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(_rgb(_paintedShadow(tester)), _rgb(kOpenHead),
          reason: '🔴 le maillon « jeton » de la chaîne par type n\'est pas '
              'consulté : la chaîne relayée n\'est pas celle de la carte');
    });
  });

  group('🧊 inertie — sans preset, AUCUNE ombre dans l\'arbre', () {
    testWidgets('aucun preset : la boîte d\'ombre est ABSENTE',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        _session(type: ZFlashcardType.openQuestion),
        withResolver: true,
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(ZFlashcardReviewCard.shadowKey), findsNothing,
          reason: '🔴 une ombre est apparue alors qu\'aucun preset n\'est '
              'posé (AD-4)');
      // Non-vacuité : la carte, elle, est bien montée.
      expect(find.byType(ZFlashcardReviewCard), findsWidgets);
    });
  });

  group('🥇 priorité — teinte EXPLICITE > direction du preset', () {
    testWidgets('`ZCardChromeSpec.shadowColor` bat la teinte du type',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        _session(
          type: ZFlashcardType.openQuestion,
          preset: ZStudySessionPreset(
            // Les DEUX canaux sont posés : sans le résolveur, une inversion de
            // priorité resterait invisible et la garde ne mesurerait qu'un
            // relais, pas un ordre.
            cardChrome: (ZFlashcard card) => const ZCardChromeSpec(
              shadowColor: kExplicitShadow,
              shadowColorResolver: zFlashcardTypeShadowColor,
            ),
          ),
        ),
        withResolver: true,
      ));
      await tester.pumpAndSettle();

      expect(_rgb(_paintedShadow(tester)), _rgb(kExplicitShadow));
      // Non-vacuité : la teinte du type est résoluble ici, et elle a perdu.
      expect(_rgb(kExplicitShadow), isNot(_rgb(kOpenHead)));
    });

    testWidgets('`classic(cardShadowColor:)` bat la teinte du type',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        _session(
          type: ZFlashcardType.openQuestion,
          preset: ZStudySessionPreset.classic(
            cardShadowColor: kExplicitShadow,
          ),
        ),
        withResolver: true,
      ));
      await tester.pumpAndSettle();
      expect(_rgb(_paintedShadow(tester)), _rgb(kExplicitShadow));
    });
  });

  group('🎟️ le jeton de thème garde la main quand le preset se tait', () {
    testWidgets('preset NU + jeton posé ⇒ c\'est le JETON qui peint',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        _session(
          type: ZFlashcardType.openQuestion,
          preset: const ZStudySessionPreset(),
        ),
        withResolver: true,
        theme: _theme(
          tune: (ZcrudTheme base) =>
              base.copyWith(flashcardCardShadowColor: kTokenShadow),
        ),
      ));
      await tester.pumpAndSettle();
      expect(_rgb(_paintedShadow(tester)), _rgb(kTokenShadow),
          reason: '🔴 un preset qui ne décrit AUCUNE ombre a écrasé le jeton '
              'de thème par un `null` explicite');
    });

    testWidgets('`.classic` + type INCONNU de toute la chaîne ⇒ le JETON peint',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        // Aucun résolveur, aucun jeton de dégradés par type : la chaîne par
        // type se tait entièrement, et le maillon suivant doit reprendre.
        _session(
          type: ZFlashcardType.multipleChoice,
          preset: ZStudySessionPreset.classic(),
        ),
        theme: _theme(
          tune: (ZcrudTheme base) =>
              base.copyWith(flashcardCardShadowColor: kTokenShadow),
        ),
      ));
      await tester.pumpAndSettle();
      expect(_rgb(_paintedShadow(tester)), _rgb(kTokenShadow),
          reason: '🔴 `.classic` a rendu une teinte fabriquée là où la chaîne '
              'par type ne résout rien — le jeton devient inexprimable');
    });
  });

  group('🔗 aucune RÉÉCRITURE de la chaîne dans `preset/` — un seul canal', () {
    test('les trois motifs de maillon sont ABSENTS de tout `preset/`', () {
      final Map<String, String> sources = _presetSources();
      // Non-vacuité : sans elle, un chemin cassé rendrait la garde verte en
      // ne scannant rien.
      expect(sources, isNotEmpty, reason: '🔴 aucun fichier `preset/` scanné');
      expect(
        sources.keys.any((String p) => p.endsWith('z_card_type_shadow.dart')),
        isTrue,
        reason: '🔴 le relais de teinte n\'est plus dans le balayage : la '
            'garde ne mesure plus rien',
      );

      expect(zChainRewritesIn(sources), isEmpty,
          reason: '🔴 un fichier de `preset/` recompose la chaîne de '
              'résolution du dégradé de type au lieu d\'appeler '
              '`zResolveFlashcardTypeGradient` : deux ordres à maintenir, et '
              'rien ne garantit qu\'ils restent égaux');
    });

    test('le relais APPELLE le foyer unique publié en amont', () {
      final String relais = zsrc.strippedOf(
        'lib/src/presentation/preset/z_card_type_shadow.dart',
      );
      expect(relais.contains('zResolveFlashcardTypeGradient('), isTrue,
          reason: '🔴 le relais ne passe pas par la fonction publique amont');
    });

    test('aucune clé de type recopiée en littéral dans ce paquet', () {
      final String relais = zsrc.strippedOf(
        'lib/src/presentation/preset/z_card_type_shadow.dart',
      );
      expect(relais.contains("'flashcard.type."), isFalse,
          reason: '🔴 le préfixe est recopié au lieu d\'être importé');
    });

    test('CONTRE-PREUVE — un fichier synthétique de `preset/` portant '
        '`zResolveGradient(` est DÉTECTÉ', () {
      // Le détecteur exercé ici est CELUI de la garde ci-dessus, pas une
      // copie : seule l'entrée change. Écrire ce fichier sur disque ferait
      // rougir, au hasard de l'ordonnancement, les autres gardes de source
      // du paquet qui balaient `lib/` en parallèle.
      const String faux = 'lib/src/presentation/preset/z_faux_relais.dart';
      expect(
        zChainRewritesIn(<String, String>{
          faux: 'final s = zResolveGradient(context, typeName);',
        }),
        contains(startsWith(faux)),
      );
      expect(
        zChainRewritesIn(<String, String>{
          faux: 'final s = ZcrudTheme.of(context)'
              '.flashcardTypeGradients?[typeName];',
        }),
        contains(startsWith(faux)),
      );
      expect(
        zChainRewritesIn(<String, String>{
          faux: "const k = '\$kZFlashcardReviewTypeGradientKeyPrefix\$t';",
        }),
        contains(startsWith(faux)),
      );
      // Et l'appel légitime au foyer unique, lui, ne déclenche RIEN : sans
      // cette moitié, un détecteur qui rougirait sur tout serait « vert ».
      expect(
        zChainRewritesIn(<String, String>{
          faux: 'final s = zResolveFlashcardTypeGradient(context, card);',
        }),
        isEmpty,
      );
    });
  });

  group('🧱 AD-4 — `.classic` ne fabrique jamais un chrome VIDE', () {
    test('le chrome de `.classic` ne porte QUE la direction d\'ombre', () {
      final ZStudySessionPreset preset = ZStudySessionPreset.classic();
      final ZCardChromeSpecBuilder? builder = preset.cardChrome;
      expect(builder, isNotNull,
          reason: '🔴 la direction d\'ombre de `.classic` n\'est pas décrite');
      final ZCardChromeSpec spec =
          builder!(_typed(ZFlashcardType.openQuestion));
      expect(spec.shadowColorResolver, isNotNull);
      expect(spec.shadowColor, isNull);
      expect(spec.typeGradientKey, isNull);
      expect(spec.instructionBanner, isNull);
      expect(spec.questionTypeBadgeBuilder, isNull);
      expect(spec.accentHeight, isNull);
    });

    test('un chrome sans aucune teinte ne résout RIEN hors contexte', () {
      const ZCardChromeSpec nu = ZCardChromeSpec();
      expect(nu.shadowColor, isNull);
      expect(nu.shadowColorResolver, isNull);
    });
  });
}
