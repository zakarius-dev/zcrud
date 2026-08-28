// GARDE du repli INERTE de lecture audio.
//
// Ce que la garde ferme : un repli « inerte » qui ment. Trois façons de mentir,
// toutes plausibles à l'écriture et invisibles à la compilation :
//   * rendre `Right(unit)` sur une opération — l'appelant croit le son joué,
//     ne voit aucune erreur, et cherche le défaut côté volume ;
//   * exposer un flux qui ne se ferme JAMAIS — un `await for` sur `position`
//     suspend l'appelant indéfiniment, sans erreur ni événement ;
//   * annoncer `isAvailable == true` sans moteur.
//
// Les flux sont donc mesurés sous DÉLAI BORNÉ : un flux qui ne se ferme pas
// fait échouer le test par timeout, jamais pendre la suite.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';

/// Délai au-delà duquel un flux qui devait être CLOS est déclaré pendant.
const Duration _borne = Duration(seconds: 2);

void main() {
  group('ZInertAudioPlaybackPort', () {
    // `const` : le repli n'a aucun état, et le contexte const le prouve.
    const ZInertAudioPlaybackPort port = ZInertAudioPlaybackPort();

    test('annonce honnêtement son indisponibilité', () {
      expect(port.isAvailable, isFalse);
      expect(port.duration, isNull);
      expect(port, isA<ZAudioPlaybackPort>());
    });

    test('CHAQUE opération rend un Left typé nommant le membre appelé',
        () async {
      final Map<String, ZResult<Unit>> resultats = <String, ZResult<Unit>>{
        'load': await port.load(const ZAudioSource.url('https://exemple/a.mp3')),
        'play': await port.play(),
        'pause': await port.pause(),
        'seek': await port.seek(const Duration(seconds: 3)),
      };
      expect(resultats.length, 4);

      for (final MapEntry<String, ZResult<Unit>> e in resultats.entries) {
        expect(e.value.isLeft(), isTrue,
            reason: '🔴 `${e.key}` rend un SUCCÈS sans jouer de son — '
                'l\'appelant ne peut plus distinguer « joué » de « rien »');
        final ZFailure echec = e.value.fold((ZFailure f) => f, (_) => throw 0);
        expect(echec, isA<ZUnsupportedOperationFailure>(),
            reason: 'capacité absente ≠ panne : le type doit le dire');
        expect((echec as ZUnsupportedOperationFailure).operation, e.key,
            reason: 'le diagnostic doit nommer le membre appelé, sans parser '
                'le message');
      }
    });

    test('les deux flux sont CLOS et n\'émettent rien (délai borné)', () async {
      expect(await port.position.toList().timeout(_borne), isEmpty,
          reason: '🔴 `position` émet ou ne se ferme pas');
      expect(await port.state.toList().timeout(_borne), isEmpty,
          reason: '🔴 `state` émet ou ne se ferme pas');
    });

    test('`dispose` termine et reste idempotent', () async {
      await port.dispose().timeout(_borne);
      await port.dispose().timeout(_borne);
      // …et l'inertie survit à la libération.
      expect((await port.play()).isLeft(), isTrue);
    });
  });

  group('ZAudioSource', () {
    test('les trois provenances portent leur kind et leur localisation', () {
      expect(const ZAudioSource.url('https://x/a.mp3').kind,
          ZAudioSourceKind.url);
      expect(const ZAudioSource.asset('assets/a.mp3').kind,
          ZAudioSourceKind.asset);
      expect(const ZAudioSource.file('/tmp/a.mp3').kind, ZAudioSourceKind.file);
      expect(const ZAudioSource.file('/tmp/a.mp3').location, '/tmp/a.mp3');
    });

    test('est un TYPE DE VALEUR : le kind discrimine à localisation égale', () {
      expect(const ZAudioSource.url('a'), const ZAudioSource.url('a'));
      expect(const ZAudioSource.url('a').hashCode,
          const ZAudioSource.url('a').hashCode);
      expect(const ZAudioSource.url('a'), isNot(const ZAudioSource.url('b')));
      expect(const ZAudioSource.url('a'), isNot(const ZAudioSource.file('a')),
          reason: '🔴 deux provenances confondues : une implémentation '
              'rechargerait la mauvaise source');
    });
  });

  group('ZAudioPlaybackState', () {
    test('six états, nommés en camelCase (convention de persistance)', () {
      expect(ZAudioPlaybackState.values, hasLength(6));
      expect(
        ZAudioPlaybackState.values.map((ZAudioPlaybackState s) => s.name),
        <String>['idle', 'loading', 'playing', 'paused', 'completed', 'failed'],
      );
    });
  });
}
