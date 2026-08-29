@TestOn('vm')
/// Politique de SOURCE du mini-lecteur audio (FR-26 / AD-13), tenue par machine.
///
/// ## Pourquoi une garde de SOURCE et pas seulement une garde de rendu
///
/// Un libellé codé en dur ou une couleur littérale **rendent verts** tous les
/// tests de comportement : le widget s'affiche, le tap fonctionne, la sémantique
/// existe. Seule une lecture de la source établit que le texte affiché vient
/// bien du mécanisme de libellés et que la couleur vient bien d'un rôle du
/// thème.
///
/// ## Découpage assumé
///
/// `z_note_audio_player.dart` (le widget) ne porte **aucun** texte affichable ni
/// aucune couleur littérale. `z_note_audio_labels.dart` est le **fichier de
/// référence unique** qui, lui, porte les défauts de libellés — il est exempté
/// **nominativement**, et lui seul (patron FR-26 encadré).
///
/// ⚠️ `dart:io` ⇒ `@TestOn('vm')`.
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/z_sources.dart' as z_sources;

/// Chemin du widget — la SEULE cible de cette garde.
const String _playerPath = 'lib/src/presentation/z_note_audio_player.dart';

/// Fichier de RÉFÉRENCE exempté nominativement (et lui seul).
const String _labelsPath = 'lib/src/presentation/z_note_audio_labels.dart';

/// Source du widget, commentaires DÉPOUILLÉS (la dartdoc décrit le contrat et
/// n'est pas du code).
String _playerSource() => z_sources.stripCommentsOf(File(_playerPath));

/// Lignes de code du widget, directives d'import/export/part/library retirées.
///
/// Les URI de directive sont des littéraux légitimes : elles ne s'affichent
/// jamais.
List<String> _playerCodeLines() => _playerSource()
    .split('\n')
    .where(
      (String l) => !RegExp(r'^\s*(import|export|part|library)\b').hasMatch(l),
    )
    .toList();

/// Littéraux de chaîne d'une ligne, réduits à leur part **littérale** :
/// l'interpolation (`$x`, `${…}`) est retirée, puisqu'elle ne fabrique aucun
/// texte en dur.
Iterable<String> _hardcodedTextOf(String line) => RegExp(
  '\'(?:[^\'\\\\\n]|\\\\.)*\'|"(?:[^"\\\\\n]|\\\\.)*"',
).allMatches(line).map((RegExpMatch m) {
  final String raw = m.group(0)!;
  return raw
      .substring(1, raw.length - 1)
      .replaceAll(RegExp(r'\$\{[^}]*\}'), '')
      .replaceAll(RegExp(r'\$\w+'), '')
      .trim();
}).where((String s) => s.isNotEmpty);

void main() {
  group('FR-26 — le widget du lecteur ne code EN DUR ni texte ni couleur', () {
    setUpAll(() {
      expect(File(_playerPath).existsSync(), isTrue,
          reason: 'le widget a été déplacé/supprimé : RE-STATUER la garde.');
      expect(File(_labelsPath).existsSync(), isTrue,
          reason: 'le fichier de référence des libellés a disparu : les défauts '
              'sont donc revenus quelque part — RE-STATUER la garde.');
    });

    test('⛔ AUCUN texte affichable codé en dur dans le widget', () {
      final List<String> coupables = <String>[];
      for (final String line in _playerCodeLines()) {
        for (final String text in _hardcodedTextOf(line)) {
          coupables.add('« $text » dans : ${line.trim()}');
        }
      }
      expect(
        coupables,
        isEmpty,
        reason: 'FR-26 : tout texte affiché par le lecteur passe par '
            '`zResolveNoteAudioLabel` (surcharge `ZcrudScope(labels:)` → '
            '`ZcrudLocalizations` → défaut du paquet). Les défauts vivent dans '
            '$_labelsPath, jamais dans le widget.',
      );
    });

    test('⛔ AUCUNE couleur littérale dans le widget (rôles M3 seulement)', () {
      final String src = _playerSource();
      for (final String banned in const <String>[
        'Colors.',
        'Color(0x',
        'Color.fromARGB',
        'Color.fromRGBO',
      ]) {
        expect(src, isNot(contains(banned)),
            reason: 'FR-26 : la couleur vient d\'un RÔLE du ColorScheme '
                '(`error`, …) ou du thème ambiant, jamais d\'un littéral.');
      }
      expect(src, isNot(matches(RegExp(r'0x[0-9a-fA-F]{6,8}'))),
          reason: 'FR-26 : aucun hexadécimal de couleur.');
    });

    test('✅ le widget RÉSOUT ses libellés par le mécanisme l10n du paquet', () {
      final String src = _playerSource();
      expect(src, contains('zResolveNoteAudioLabel'),
          reason: 'sans résolution, un libellé serait forcément codé en dur.');
      // Chaque clé déclarée par la référence est effectivement CONSOMMÉE : une
      // clé orpheline signalerait un libellé perdu ou un contrôle non étiqueté.
      for (final String key in const <String>[
        'kZNoteAudioPlayLabelKey',
        'kZNoteAudioPauseLabelKey',
        'kZNoteAudioLoadingLabelKey',
        'kZNoteAudioFailedLabelKey',
        'kZNoteAudioSeekLabelKey',
        'kZNoteAudioElapsedLabelKey',
      ]) {
        expect(src, contains(key), reason: '$key n\'est consommée nulle part.');
      }
    });

    test('✅ le widget ne dispose JAMAIS le port (propriété de l\'hôte)', () {
      expect(
        _playerSource(),
        isNot(contains('port.dispose()')),
        reason: 'le port appartient à l\'appelant : le disposer ici couperait '
            'le son d\'un autre écran partageant le même moteur.',
      );
    });
  });
}
