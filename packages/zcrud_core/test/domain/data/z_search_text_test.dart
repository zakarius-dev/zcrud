// AC1 (E4-3, AD-10) : `zFoldDiacritics` — normalisation de texte NEUTRE et PURE
// pour la recherche SANS ACCENTS. Pliage diacritique (table Latin), abaissement
// de casse, idempotence, chaîne vide. Pur-Dart (aucun widget/dart:ui).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  test('replie les diacritiques Latin courants + abaisse la casse (AC1)', () {
    expect(zFoldDiacritics('Café'), 'cafe');
    expect(zFoldDiacritics('ÉÈÊË'), 'eeee');
    expect(zFoldDiacritics('Élève'), 'eleve');
    expect(zFoldDiacritics('Ça'), 'ca');
    expect(zFoldDiacritics('Niño'), 'nino');
    expect(zFoldDiacritics('Über'), 'uber');
  });

  test('déplie les ligatures multi-caractères (AC1)', () {
    expect(zFoldDiacritics('Œuvre'), 'oeuvre');
    expect(zFoldDiacritics('Æon'), 'aeon');
    expect(zFoldDiacritics('Straße'), 'strasse');
  });

  test('chaîne vide → chaîne vide, ne lève jamais (AC1)', () {
    expect(zFoldDiacritics(''), '');
    expect(zFoldDiacritics('   '), '   ');
  });

  test('idempotence : replier une chaîne déjà repliée est un no-op (AC1)', () {
    const samples = ['café', 'œuvre', 'straße', 'élève', 'abc123'];
    for (final s in samples) {
      final once = zFoldDiacritics(s);
      expect(zFoldDiacritics(once), once, reason: 'idempotent sur "$s"');
    }
  });

  test('déterministe : même entrée → même sortie (AC1)', () {
    expect(zFoldDiacritics('Crème Brûlée'), zFoldDiacritics('Crème Brûlée'));
    expect(zFoldDiacritics('Crème Brûlée'), 'creme brulee');
  });

  test('les caractères non diacritiques sont préservés (AC1)', () {
    expect(zFoldDiacritics('Hello-World_42'), 'hello-world_42');
  });
}
