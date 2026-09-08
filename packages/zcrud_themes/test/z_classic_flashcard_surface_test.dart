@TestOn('vm')
library;

// Les TROIS jetons de couleur de l'écran de révision : ce que le thème pose,
// ce qu'il laisse délibérément vide, et pourquoi le rendu ne bouge pas sans
// lui.
//
// 🔴 Pourquoi une garde de SOURCE et non un widget monté : les trois jetons
// sont consommés par `zcrud_study`, dont ce paquet n'a PAS d'arête (et ne doit
// pas en ouvrir une : elle entrerait dans le graphe mesuré par `graph_proof`).
// Le consommateur ne peut donc pas être monté ici. La garde lit sa source sur
// disque et vérifie la CHAÎNE réellement écrite — patron déjà employé par
// `z_socle_gradient_parity_test.dart`.
//
// Ce que la chaîne prouve : le dernier maillon de chacune des trois est un
// RÔLE de l'hôte. Un jeton laissé `null` retombe donc exactement sur le rendu
// d'aujourd'hui — c'est l'inertie, et elle est mesurée sur le code du
// consommateur, pas supposée.
//
// La morsure est prouvée des deux côtés : l'extraction est une fonction pure
// du texte, et les contre-preuves mutent ce texte EN MÉMOIRE — jamais sur
// disque, ce paquet n'étant pas le rédacteur de `zcrud_study`.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_themes/zcrud_themes.dart';

import 'z_package_root.dart';

/// Source du consommateur de la carte de flashcard, relative à la racine du
/// monorepo.
const String kZCardConsumerPath =
    'packages/zcrud_study/lib/src/presentation/z_default_flashcard_card.dart';

/// Source du consommateur du chrome de l'écran de session.
const String kZSessionConsumerPath =
    'packages/zcrud_study/lib/src/presentation/z_study_session_reference.dart';

/// Le texte de [path], lu sur disque.
///
/// Lève si le fichier a bougé : une garde qui ne trouve plus sa source doit
/// rougir, jamais se taire.
String zReadConsumerSource(String path) {
  final File file = File('${zMonorepoRoot().path}/$path');
  if (!file.existsSync()) {
    throw StateError(
      'Consommateur introuvable : ${file.path}. La garde ne mesure plus '
      'rien — corrigez le chemin.',
    );
  }
  return file.readAsStringSync();
}

/// Retire les commentaires de [source] et aplatit les blancs : les motifs
/// ciblent le CODE, et une chaîne `??` s'écrit sur plusieurs lignes.
String _codeOf(String source) => source
    .split('\n')
    .map((String line) {
      final int i = line.indexOf('//');
      return i < 0 ? line : line.substring(0, i);
    })
    .join(' ')
    .replaceAll(RegExp(r'\s+'), ' ');

/// Les opérandes, DANS L'ORDRE, de la chaîne `??` qui traverse `theme.[token]`
/// dans [source].
///
/// Rend `[paramètre, jeton, repli]`. Lève un [StateError] si la chaîne est
/// absente : une garde qui rendrait une liste vide sur un reformatage
/// resterait verte en ne mesurant plus rien.
List<String> zParseTokenChain(String source, String token) {
  final RegExpMatch? m = RegExp(
    r'(\w+)\s*\?\?\s*theme\.' + token + r'\s*\?\?\s*([\w.]+)',
  ).firstMatch(_codeOf(source));
  if (m == null) {
    throw StateError(
      'Chaîne de résolution de `$token` introuvable chez le consommateur : '
      'la garde ne mesure plus rien.',
    );
  }
  return <String>[m.group(1)!, 'theme.$token', m.group(2)!];
}

void main() {
  group('fond de carte — le jeton POSÉ', () {
    test('la valeur posée est celle du relevé, par luminosité', () {
      // Égalité STRICTE sur l'entier ARGB : `Color` compare aussi son espace
      // colorimétrique, et une garde qui s'en remettrait à `==` seul pourrait
      // rester verte sur une valeur recomposée autrement.
      expect(
        ZClassicTheme.forTheme(ThemeData(brightness: Brightness.dark))
            .flashcardCardBackgroundColor
            ?.toARGB32(),
        ZClassicSurfaceReference.darkCard.toARGB32(),
      );
      expect(
        ZClassicTheme.forTheme(ThemeData(brightness: Brightness.light))
            .flashcardCardBackgroundColor
            ?.toARGB32(),
        ZClassicSurfaceReference.lightCard.toARGB32(),
      );
    });

    test('le mode CLAIR ne reçoit jamais la valeur SOMBRE', () {
      // Le risque exact que ce thème court : les valeurs relevées sont
      // sombres, et les poser sans distinguer la luminosité peindrait une
      // carte presque noire sur un écran clair.
      final int? light = ZClassicTheme
          .forTheme(ThemeData(brightness: Brightness.light))
          .flashcardCardBackgroundColor
          ?.toARGB32();
      expect(light, isNotNull);
      expect(light, isNot(ZClassicSurfaceReference.darkCard.toARGB32()));
      expect(
        ZClassicTheme.forTheme(ThemeData(brightness: Brightness.dark))
            .flashcardCardBackgroundColor
            ?.toARGB32(),
        isNot(light),
        reason: 'Les deux modes rendent la même couleur : le thème ne '
            'distingue plus la luminosité.',
      );
    });
  });

  group('les deux jetons DÉLIBÉRÉMENT non posés', () {
    test('ombre de carte et séparateur de session restent `null`', () {
      // Aucune valeur mesurable n'existe pour eux dans le code de référence :
      // l'ombre y est dérivée du dégradé du TYPE de carte (quatre couleurs
      // pour un jeton qui n'en porte qu'une), et l'écran de session ne trace
      // aucun trait. Les laisser vides rend le rôle de l'hôte ; les remplir
      // inventerait une valeur.
      for (final Brightness b in Brightness.values) {
        final ZcrudTheme t = ZClassicTheme.forTheme(ThemeData(brightness: b));
        expect(t.flashcardCardShadowColor, isNull, reason: '$b');
        expect(t.studySessionDividerColor, isNull, reason: '$b');
        // Non-vacuité : sans elle, un thème devenu entièrement vide
        // passerait ce test sans rien prouver.
        expect(t.flashcardCardBackgroundColor, isNotNull, reason: '$b');
      }
    });
  });

  group('inertie — sans le thème, le rendu d\'aujourd\'hui', () {
    test('les trois jetons sont vides dans le repli du socle', () {
      for (final Brightness b in Brightness.values) {
        final ZcrudTheme f = ZcrudTheme.fallback(ThemeData(brightness: b));
        expect(f.flashcardCardBackgroundColor, isNull, reason: '$b');
        expect(f.flashcardCardShadowColor, isNull, reason: '$b');
        expect(f.studySessionDividerColor, isNull, reason: '$b');
      }
    });

    test('chaque chaîne du consommateur retombe sur un RÔLE de l\'hôte', () {
      // C'est cela, l'inertie : jeton vide ⇒ dernier maillon ⇒ rôle ⇒ rendu
      // inchangé. La garde lit les trois chaînes réellement écrites.
      final String card = zReadConsumerSource(kZCardConsumerPath);
      final String session = zReadConsumerSource(kZSessionConsumerPath);

      expect(
        zParseTokenChain(card, 'flashcardCardBackgroundColor'),
        <String>[
          'backgroundColor',
          'theme.flashcardCardBackgroundColor',
          'material.scaffoldBackgroundColor',
        ],
      );
      expect(
        zParseTokenChain(card, 'flashcardCardShadowColor'),
        <String>[
          'shadowColor',
          'theme.flashcardCardShadowColor',
          'material.shadowColor',
        ],
      );
      expect(
        zParseTokenChain(session, 'studySessionDividerColor'),
        <String>[
          'dividerColor',
          'theme.studySessionDividerColor',
          'scheme.outlineVariant',
        ],
      );
    });

    test('le jeton est au MILIEU : un paramètre de widget passe devant', () {
      // La chaîne `paramètre > jeton > rôle` est ordonnée. Vérifier seulement
      // la présence des trois noms laisserait passer un ordre inversé, où le
      // thème écraserait le paramètre de l'appelant.
      for (final List<String> chain in <List<String>>[
        zParseTokenChain(
            zReadConsumerSource(kZCardConsumerPath),
            'flashcardCardBackgroundColor'),
        zParseTokenChain(
            zReadConsumerSource(kZCardConsumerPath),
            'flashcardCardShadowColor'),
        zParseTokenChain(
            zReadConsumerSource(kZSessionConsumerPath),
            'studySessionDividerColor'),
      ]) {
        expect(chain, hasLength(3));
        expect(chain[1], startsWith('theme.'));
        expect(chain.first, isNot(startsWith('theme.')));
        expect(chain.last, contains('.'));
      }
    });
  });

  group('la garde MORD (source du consommateur mutée en mémoire)', () {
    test('un repli changé de rôle est vu', () {
      final String source = zReadConsumerSource(kZCardConsumerPath);
      final String mute = source.replaceFirst(
        'material.scaffoldBackgroundColor',
        'material.canvasColor',
      );
      expect(mute, isNot(source), reason: 'mutation non appliquée');
      expect(
        zParseTokenChain(mute, 'flashcardCardBackgroundColor').last,
        'material.canvasColor',
      );
    });

    test('un jeton retiré de la chaîne LÈVE', () {
      final String source = zReadConsumerSource(kZCardConsumerPath);
      final String mute = source.replaceFirst(
        'theme.flashcardCardBackgroundColor ??',
        '',
      );
      expect(mute, isNot(source), reason: 'mutation non appliquée');
      expect(
        () => zParseTokenChain(mute, 'flashcardCardBackgroundColor'),
        throwsStateError,
      );
    });

    test('un jeton jamais consommé LÈVE, au lieu de rendre la garde creuse',
        () {
      expect(
        () => zParseTokenChain(
          zReadConsumerSource(kZCardConsumerPath),
          'studySessionDividerColor',
        ),
        throwsStateError,
      );
    });

    test('un consommateur déplacé LÈVE', () {
      expect(
        () => zReadConsumerSource('packages/zcrud_study/lib/introuvable.dart'),
        throwsStateError,
      );
    });
  });
}
