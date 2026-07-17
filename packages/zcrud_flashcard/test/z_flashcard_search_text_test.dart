// Tests de `zFlashcardSearchText` (SU-8/AC4, D5).
//
// 🔴 Le test central est « eleve trouve élève en NFC **ET EN NFD** » : c'est le
// seul qui distingue la délégation NUE à `zFoldDiacritics` (limite L-2, NFD non
// replié) de la normalisation réellement livrée par su-8.
//
// Runner : `flutter_test` (le package est Flutter) — mais la fonction est PURE
// et testable hors widget (AC4).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// `é` **précomposé** (NFC) — U+00E9, une seule rune.
const String _eAiguNfc = 'é';

/// `é` **décomposé** (NFD) — `e` + U+0301 (accent combinant), DEUX runes.
const String _eAiguNfd = 'é';

void main() {
  group('AC4 — délégation à zFoldDiacritics (table UNIQUE dans zcrud_core)', () {
    test('les replis du cœur sont conservés (jamais réimplémentés)', () {
      // Ces cas sont ceux de `zFoldDiacritics` : su-8 ne les recode pas, il les
      // HÉRITE. S'ils cassaient, c'est la table du cœur qui aurait bougé.
      expect(zFlashcardSearchText('Café'), 'cafe');
      expect(zFlashcardSearchText('ÉÈÊË'), 'eeee');
      expect(zFlashcardSearchText('Ça'), 'ca');
      expect(zFlashcardSearchText('Œuvre'), 'oeuvre');
      expect(zFlashcardSearchText('Æquo'), 'aequo');
      expect(zFlashcardSearchText('Straße'), 'strasse');
      expect(zFlashcardSearchText('Ñandú'), 'nandu');
    });
  });

  group('🔴 AC4 — NFD : le manque RÉEL que su-8 comble (limite L-2)', () {
    test('« é » NFC et NFD se replient TOUS DEUX sur « e »', () {
      expect(_eAiguNfc.runes.length, 1, reason: 'sanity : NFC = 1 rune');
      expect(_eAiguNfd.runes.length, 2, reason: 'sanity : NFD = e + combinant');
      expect(_eAiguNfc == _eAiguNfd, isFalse,
          reason: '🔴 les deux chaînes sont DIFFÉRENTES pour Dart — c\'est '
              'exactement pourquoi une recherche naïve échoue');

      expect(zFlashcardSearchText(_eAiguNfc), 'e');
      expect(zFlashcardSearchText(_eAiguNfd), 'e',
          reason: '🔴 L-2 : `zFoldDiacritics` seul laisserait le rune combinant '
              '⇒ « eleve » ne trouverait PAS « élève » saisi en NFD');
    });

    test('🔴 « eleve » trouve « élève » en NFC **ET** en NFD (AC4 verbatim)', () {
      const query = 'eleve';
      final nfc = 'élève'; // é + è précomposés
      final nfd = 'élève'; // é + è décomposés

      expect(zFlashcardSearchText(nfc), query);
      expect(zFlashcardSearchText(nfd), query,
          reason: '🔴 le cas NFD est le cœur d\'AC4 : une carte importée d\'une '
              'source macOS/iOS est souvent en NFD — sans strip, elle serait '
              'INTROUVABLE alors que la recherche est juste');
    });

    test('un combinant SANS base (dégénéré) ⇒ jamais de throw', () {
      expect(zFlashcardSearchText('́'), '');
      expect(zFlashcardSearchText('́̀'), '');
    });
  });

  group('🔴 AC4/D7 — le strip NFD est BORNÉ au latin (aucune confusion non-latine)', () {
    test('🔴 cyrillique : « и »+brève (й NFD) N\'EST PAS réduit à « и »', () {
      // Escapes explicites (\u) : indépendant de toute (re)normalisation d'éditeur.
      const iBref = '\u0438\u0306'; // и + U+0306 = « й » décomposé (NFD)
      const i = '\u0438'; // « и » seul (une AUTRE lettre du russe)
      expect(iBref.runes.length, 2, reason: 'sonde : NFD = base + combinant');

      expect(zFlashcardSearchText(iBref) == zFlashcardSearchText(i), isFalse,
          reason: '🔴 stripper la brève transformerait « й » en « и » — une '
              'lettre DIFFÉRENTE du russe. « мой » (NFD) serait indexé « мои » '
              'et remonterait sur « les miens » : faux positif SILENCIEUX');
      expect(zFlashcardSearchText(iBref).runes.contains(0x0306), isTrue,
          reason: 'base non-latine : la marque est CONSERVÉE telle quelle');
    });

    test('grec : « ο »+tonos décomposé conserve sa marque (non replié)', () {
      const oTonos = '\u03bf\u0301'; // ο + U+0301
      expect(zFlashcardSearchText(oTonos).runes.contains(0x0301), isTrue,
          reason: 'base grecque : ni repliée par la table latine, ni corrompue');
    });

    test('latin : le strip fonctionne TOUJOURS (base latine ⇒ marque retirée)', () {
      expect(zFlashcardSearchText('e\u0301'), 'e'); // é NFD
      expect(zFlashcardSearchText('E\u0301le\u0300ve'), 'eleve', // Élève NFD
          reason: 'régression D7 : le latin doit rester replié comme avant');
    });

    test('marque combinante orpheline (aucune base) ⇒ retirée', () {
      expect(zFlashcardSearchText('\u0301'), '');
      expect(zFlashcardSearchText('\u0301\u0300'), '');
    });
  });

  group('AC4 — espaces (le 2e manque : zFoldDiacritics n\'en normalise aucun)', () {
    test('trim + runs d\'espaces repliés en un seul', () {
      expect(zFlashcardSearchText('  Élève   ÂGÉ  '), 'eleve age');
      expect(zFlashcardSearchText('a\t\tb'), 'a b');
      expect(zFlashcardSearchText('a\n\nb'), 'a b');
    });

    test('espace INSÉCABLE (U+00A0) replié — cas du copier-coller réel', () {
      expect(zFlashcardSearchText('a b'), 'a b',
          reason: 'un insécable non replié ⇒ « a b » ne trouve pas « a b »');
      expect(zFlashcardSearchText('a b'), 'a b');
    });

    test('espaces SEULS ⇒ chaîne vide, jamais de throw', () {
      expect(zFlashcardSearchText('   '), '');
      expect(zFlashcardSearchText(' '), '');
      expect(zFlashcardSearchText('\t\n '), '');
    });
  });

  group('AC4 — bornes Unicode : totale, jamais de throw (AD-10)', () {
    test('chaîne vide ⇒ chaîne vide', () {
      expect(zFlashcardSearchText(''), '');
    });

    test('turc : İ et ı', () {
      // `ı` (i sans point) est dans la table du cœur ⇒ 'i'.
      expect(zFlashcardSearchText('ı'), 'i');
      // `İ` (I avec point) : toLowerCase le décompose en 'i' + U+0307 (combinant
      // au-dessus) — que le strip NFD retire. Sans le strip, il subsisterait.
      expect(zFlashcardSearchText('İ'), 'i',
          reason: 'le strip NFD couvre aussi la décomposition produite par '
              'toLowerCase du İ turc');
    });

    test('emoji PRÉSERVÉ (jamais de crash sur les paires de substitution)', () {
      expect(zFlashcardSearchText('café 🎉'), 'cafe 🎉');
      expect(zFlashcardSearchText('🎉'), '🎉');
      // Emoji hors BMP = 2 codeUnits : une itération sur codeUnits le couperait.
      expect('🎉'.codeUnits.length, 2, reason: 'sanity : paire de substitution');
      expect(zFlashcardSearchText('👨‍👩‍👧'), '👨‍👩‍👧',
          reason: 'séquence ZWJ : préservée telle quelle, jamais de throw');
    });

    test('CJK / chiffres / ponctuation : préservés (jamais de perte muette)', () {
      expect(zFlashcardSearchText('漢字'), '漢字');
      expect(zFlashcardSearchText('Test 123 !'), 'test 123 !');
    });

    test('IDEMPOTENCE : f(f(x)) == f(x) sur tous les cas ci-dessus', () {
      const samples = <String>[
        '', '   ', 'Café', _eAiguNfd, 'İ', 'ı', 'Œuvre', 'Straße',
        'café 🎉', '漢字', 'a b', '  Élève   ÂGÉ  ', '́',
      ];
      for (final s in samples) {
        final once = zFlashcardSearchText(s);
        expect(zFlashcardSearchText(once), once,
            reason: 'non idempotent sur « $s » ⇒ le résultat dépendrait du '
                'nombre d\'applications (indexation vs requête)');
      }
    });
  });
}
