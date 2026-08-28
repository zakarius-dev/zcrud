// GARDE de PURETÉ du port de lecture audio.
//
// Ce que la garde ferme, et que `domain_purity_test.dart` ne voit pas : sa
// liste d'imports interdits énumère Flutter, les backends et les gestionnaires
// d'état — pas les MOTEURS AUDIO. Or c'est exactement la dépendance qu'un port
// audio attire : brancher `just_audio` « juste pour le type `Duration` de son
// API » ferait entrer une chaîne de build native dans `zcrud_core`, et tout
// consommateur du cœur — y compris ceux qui ne lisent aucun son — la subirait.
//
// La garde est donc NOMINATIVE sur le fichier du port, et bilatérale :
//   * aucun import hors de la liste blanche (dartz + relatifs + dart: hors ui) ;
//   * aucun nom de moteur audio connu, même en dépendance transitive déclarée ;
//   * les deux types du contrat sont bien déclarés là (sinon la garde vise un
//     fichier vide et devient VACUELLE).
//
// Accès `dart:io` ⇒ `@TestOn('vm')` : le gate `web` compile les paquets vers
// Node, où ce fichier n'aurait aucun disque à lire.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/z_sources.dart' as sources;

/// Moteurs audio connus — la dépendance que ce port ne doit JAMAIS attirer.
const List<String> _moteurs = <String>[
  'just_audio',
  'audioplayers',
  'audio_service',
  'media_kit',
  'flutter_sound',
  'assets_audio_player',
  'soundpool',
];

void main() {
  late File fichier;
  late String source;

  setUpAll(() {
    fichier = sources.libFile('domain/ports/z_audio_playback_port.dart');
    source = sources.strippedSource(fichier);
  });

  test('le port DÉCLARE bien son contrat (garde non vacuelle)', () {
    expect(source.length, greaterThan(1000),
        reason: 'fichier trop court — la garde viserait un fichier vide');
    expect(source, contains('abstract class ZAudioPlaybackPort'));
    expect(source, contains('class ZInertAudioPlaybackPort'));
    expect(source, contains('enum ZAudioPlaybackState'));
  });

  test('aucun import hors liste blanche (ni Flutter, ni dart:ui)', () {
    final List<String> imports = source
        .split('\n')
        .map((String l) => l.trimLeft())
        .where((String l) => l.startsWith('import ') || l.startsWith('export '))
        .toList();
    expect(imports, isNotEmpty, reason: 'aucun import lu — parsing cassé');

    final List<String> interdits = imports
        .where((String l) =>
            !l.contains("'package:dartz/") &&
            !RegExp(r"""['"]\.\.?/""").hasMatch(l) &&
            !(l.contains("'dart:") && !l.contains("'dart:ui")))
        .toList();
    expect(interdits, isEmpty,
        reason: '🔴 import hors liste blanche dans le port audio — le cœur '
            'doit rester pur-Dart et sans moteur :\n${interdits.join("\n")}');
  });

  test('aucun moteur audio nommé dans le fichier du port', () {
    final List<String> trouves =
        _moteurs.where((String m) => source.contains(m)).toList();
    expect(trouves, isEmpty,
        reason: '🔴 moteur audio référencé par le cœur : $trouves — le moteur '
            'vit chez l\'hôte ou dans un satellite, jamais ici');
  });

  test('aucun moteur audio dans le `pubspec.yaml` du paquet', () {
    final File pubspec = File('${sources.packageRoot().path}/pubspec.yaml');
    expect(pubspec.existsSync(), isTrue);
    final String contenu = pubspec.readAsStringSync();
    expect(contenu, contains('name: zcrud_core'), reason: 'mauvais pubspec');
    final List<String> trouves =
        _moteurs.where((String m) => contenu.contains(m)).toList();
    expect(trouves, isEmpty,
        reason: '🔴 dépendance de moteur audio déclarée par `zcrud_core` : '
            '$trouves');
  });
}
