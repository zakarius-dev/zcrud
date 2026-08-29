// Gardes du mini-lecteur audio de note (`ZNoteAudioPlayer`) et de son câblage
// opt-in dans `ZSmartNoteReader` / `ZSmartNoteEditor`.
//
// STRATÉGIE — le paquet ne tire AUCUN plugin audio : le moteur est un
// `ZAudioPlaybackPort` apporté par l'hôte. Le double de test ci-dessous est un
// port EN MÉMOIRE à compteurs : il permet de mesurer exactement ce qui est
// demandé au moteur (combien de `load`, avec quelle source, combien de `play`,
// quel `seek`) — jamais d'inférer par l'apparence.
//
// INERTIE (défaut passif) : sans `audioPort`, l'arbre rendu par le lecteur et
// par l'éditeur doit être STRICTEMENT celui d'avant ce lot — pas « proche »,
// pas « contient » : le même enfant direct, la même séquence de descendants.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';
import 'package:zcrud_note/zcrud_note.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Double de test : port de lecture EN MÉMOIRE, à compteurs.
// ═══════════════════════════════════════════════════════════════════════════
class _FakeAudioPort extends ZAudioPlaybackPort {
  _FakeAudioPort({
    this.available = true,
    this.failLoad = false,
    this.failPlay = false,
    this.total = const Duration(seconds: 60),
  });

  final bool available;
  final bool failLoad;
  final bool failPlay;
  Duration? total;

  final List<ZAudioSource> loads = <ZAudioSource>[];
  final List<Duration> seeks = <Duration>[];
  int plays = 0;
  int pauses = 0;
  int disposes = 0;

  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<ZAudioPlaybackState> _state =
      StreamController<ZAudioPlaybackState>.broadcast();

  void emitPosition(Duration p) => _position.add(p);
  void emitState(ZAudioPlaybackState s) => _state.add(s);
  Future<void> close() async {
    await _position.close();
    await _state.close();
  }

  @override
  bool get isAvailable => available;

  @override
  Duration? get duration => total;

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<ZAudioPlaybackState> get state => _state.stream;

  @override
  Future<ZResult<Unit>> load(ZAudioSource source) async {
    loads.add(source);
    return failLoad ? _left('load') : const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> play() async {
    plays++;
    return failPlay ? _left('play') : const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> pause() async {
    pauses++;
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> seek(Duration position) async {
    seeks.add(position);
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<void> dispose() async {
    disposes++;
  }

  ZResult<Unit> _left(String op) => Left<ZFailure, Unit>(
    ZUnsupportedOperationFailure('double de test', operation: op),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Fixtures
// ═══════════════════════════════════════════════════════════════════════════
const List<Map<String, dynamic>> _ops = <Map<String, dynamic>>[
  <String, dynamic>{'insert': 'Corps de note\n'},
];

ZSmartNote _noteWithUrl() => const ZSmartNote(
  title: 'Ma note',
  content: _ops,
  extension: ZNoteAudio(url: 'https://cdn.example/audio.mp3'),
);

ZSmartNote _noteWithPathAndUrl() => const ZSmartNote(
  title: 'Ma note',
  content: _ops,
  extension: ZNoteAudio(
    url: 'https://cdn.example/audio.mp3',
    path: '/var/notes/audio.mp3',
  ),
);

ZSmartNote _noteWithoutAudio() =>
    const ZSmartNote(title: 'Ma note', content: _ops);

Widget _host(Widget child) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.ltr,
    child: Scaffold(body: child),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Enfants DIRECTS de l'élément de [finder] — le site EXACT qu'un conteneur
/// ajouté modifierait.
List<Widget> _directChildren(WidgetTester tester, Finder finder) {
  final List<Element> out = <Element>[];
  tester.element(finder).visitChildren(out.add);
  return out.map((Element e) => e.widget).toList();
}

/// Séquence COMPLÈTE des types de widgets du sous-arbre de [finder] (inclus).
List<String> _subtreeTypes(WidgetTester tester, Finder finder) {
  final List<String> out = <String>[];
  void walk(Element e) {
    out.add(e.widget.runtimeType.toString());
    e.visitChildren(walk);
  }

  walk(tester.element(finder));
  return out;
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════
  // INERTIE ABSOLUE — sans `audioPort`, rien ne bouge.
  // ═════════════════════════════════════════════════════════════════════════
  group('INERTIE — sans `audioPort`, l\'arbre est STRICTEMENT celui d\'avant',
      () {
    testWidgets(
        'ZSmartNoteReader : enfant direct == le SEUL ZMarkdownReader, séquence '
        'de descendants IDENTIQUE à celle du ZMarkdownReader monté seul '
        '(aucun conteneur ajouté), même sur une note QUI PORTE un audio',
        (WidgetTester tester) async {
      // Référence FIGÉE : ce que l'adaptateur rendait AVANT ce lot — un unique
      // ZMarkdownReader avec exactement les mêmes paramètres.
      await tester.pumpWidget(
        _host(
          ZMarkdownReader(
            value: _ops,
            codec: const ZDeltaCodec(),
            label: 'Ma note',
            placeholder: 'Aucun contenu',
          ),
        ),
      );
      final List<String> reference =
          _subtreeTypes(tester, find.byType(ZMarkdownReader));
      await _settle(tester);

      // Mesure : le lecteur de note, SANS port, sur une note QUI a un audio.
      await tester.pumpWidget(_host(ZSmartNoteReader(note: _noteWithUrl())));

      expect(find.byType(ZNoteAudioPlayer), findsNothing);
      final List<Widget> children =
          _directChildren(tester, find.byType(ZSmartNoteReader));
      expect(children, hasLength(1),
          reason: 'un conteneur ajouté (Column/Padding/…) casse l\'inertie.');
      expect(children.single, isA<ZMarkdownReader>());
      expect(
        _subtreeTypes(tester, find.byType(ZMarkdownReader)),
        equals(reference),
        reason: 'INERTIE : sans port, le sous-arbre doit être ÉGAL — pas '
            'seulement « contenir » — à celui d\'avant le lot.',
      );

      await _settle(tester);
    });

    testWidgets(
        'ZSmartNoteEditor : enfant direct == le SEUL ZMarkdownField, aucun '
        'conteneur ajouté, même sur une note QUI PORTE un audio',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          ZSmartNoteEditor(note: _noteWithUrl(), onChanged: (_) {}),
        ),
      );

      expect(find.byType(ZNoteAudioPlayer), findsNothing);
      final List<Widget> children =
          _directChildren(tester, find.byType(ZSmartNoteEditor));
      expect(children, hasLength(1));
      expect(children.single, isA<ZMarkdownField>());
      // Aucun conteneur INTERPOSÉ entre l'éditeur et son champ (le `Column`
      // interne de `ZMarkdownField` lui appartient : on ne mesure QUE ce qui
      // est au-dessus du champ).
      expect(
        find.ancestor(
          of: find.byType(ZMarkdownField),
          matching: find.descendant(
            of: find.byType(ZSmartNoteEditor),
            matching: find.byType(Column),
          ),
        ),
        findsNothing,
        reason: 'INERTIE : aucun Column n\'est introduit sans port.',
      );

      await _settle(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // MONTAGE CONDITIONNEL — les trois conditions, une par une.
  // ═════════════════════════════════════════════════════════════════════════
  group('montage conditionnel du lecteur', () {
    testWidgets('port fourni mais `isAvailable == false` ⇒ AUCUN lecteur, '
        'et le moteur n\'est même pas sollicité', (WidgetTester tester) async {
      final port = _FakeAudioPort(available: false);
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(ZSmartNoteReader(note: _noteWithUrl(), audioPort: port)),
      );

      expect(find.byType(ZNoteAudioPlayer), findsNothing);
      expect(port.loads, isEmpty);
      expect(_directChildren(tester, find.byType(ZSmartNoteReader)).single,
          isA<ZMarkdownReader>());

      await _settle(tester);
    });

    testWidgets('note SANS audio + port disponible ⇒ AUCUN lecteur',
        (WidgetTester tester) async {
      final port = _FakeAudioPort();
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(ZSmartNoteReader(note: _noteWithoutAudio(), audioPort: port)),
      );

      expect(find.byType(ZNoteAudioPlayer), findsNothing);
      expect(port.loads, isEmpty);

      await _settle(tester);
    });

    testWidgets('slot audio TYPÉ mais VIDE (ni url ni path) ⇒ AUCUN lecteur',
        (WidgetTester tester) async {
      final port = _FakeAudioPort();
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(
          ZSmartNoteReader(
            note: const ZSmartNote(
              title: 'x',
              content: _ops,
              extension: ZNoteAudio(textHash: 'abc'),
            ),
            audioPort: port,
          ),
        ),
      );

      expect(find.byType(ZNoteAudioPlayer), findsNothing);
      expect(ZNoteAudioPlayer.sourceOfAudio(const ZNoteAudio(url: '')), isNull);

      await _settle(tester);
    });

    testWidgets('port disponible + audio ⇒ lecteur monté, `load` appelé UNE '
        'fois avec la source ATTENDUE (le chemin local prime sur l\'URL)',
        (WidgetTester tester) async {
      final port = _FakeAudioPort();
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(
          ZSmartNoteReader(note: _noteWithPathAndUrl(), audioPort: port),
        ),
      );
      await tester.pump();

      expect(find.byType(ZNoteAudioPlayer), findsOneWidget);
      expect(port.loads, hasLength(1));
      expect(port.loads.single,
          equals(const ZAudioSource.file('/var/notes/audio.mp3')));

      await _settle(tester);
    });

    testWidgets('`load` n\'est PAS rappelé à chaque build (rebuilds du parent)',
        (WidgetTester tester) async {
      final port = _FakeAudioPort();
      addTearDown(port.close);

      Widget build() => _host(
        ZNoteAudioPlayer(
          source: const ZAudioSource.url('https://cdn.example/audio.mp3'),
          port: port,
        ),
      );
      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pumpWidget(build());
      await tester.pump();

      expect(port.loads, hasLength(1));

      await _settle(tester);
    });

    testWidgets('le port appartient à l\'hôte : JAMAIS disposé au démontage',
        (WidgetTester tester) async {
      final port = _FakeAudioPort();
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(ZSmartNoteReader(note: _noteWithUrl(), audioPort: port)),
      );
      await tester.pump();
      await _settle(tester);

      expect(port.disposes, 0);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // CONTRÔLES
  // ═════════════════════════════════════════════════════════════════════════
  group('contrôles de lecture', () {
    testWidgets('tap sur le bouton ⇒ `play()` appelé UNE fois',
        (WidgetTester tester) async {
      final port = _FakeAudioPort();
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(
          ZNoteAudioPlayer(
            source: const ZAudioSource.url('https://cdn.example/a.mp3'),
            port: port,
          ),
        ),
      );
      await tester.pump(); // `load` résolu ⇒ état `idle`, bouton actionnable

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(port.plays, 1);
      expect(port.pauses, 0);

      await _settle(tester);
    });

    testWidgets('état `playing` ⇒ icône PAUSE ; tap ⇒ `pause()`',
        (WidgetTester tester) async {
      final port = _FakeAudioPort();
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(
          ZNoteAudioPlayer(
            source: const ZAudioSource.url('https://cdn.example/a.mp3'),
            port: port,
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      port.emitState(ZAudioPlaybackState.playing);
      await tester.pump();

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsNothing);

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(port.pauses, 1);
      expect(port.plays, 0);

      await _settle(tester);
    });

    testWidgets('déplacement du curseur ⇒ `seek(Duration)` EXACT',
        (WidgetTester tester) async {
      final port = _FakeAudioPort();
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(
          ZNoteAudioPlayer(
            source: const ZAudioSource.url('https://cdn.example/a.mp3'),
            port: port,
          ),
        ),
      );
      await tester.pump();

      final Slider slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.max, 60000.0, reason: 'échelle == durée du port.');
      slider.onChanged!(31500);
      await tester.pump();
      slider.onChangeEnd!(31500);
      await tester.pump();

      expect(port.seeks, <Duration>[const Duration(milliseconds: 31500)]);

      await _settle(tester);
    });

    testWidgets('durée INCONNUE ⇒ aucun curseur (geste sans échelle interdit), '
        'l\'horodatage reste rendu', (WidgetTester tester) async {
      final port = _FakeAudioPort(total: null);
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(
          ZNoteAudioPlayer(
            source: const ZAudioSource.url('https://cdn.example/a.mp3'),
            port: port,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Slider), findsNothing);
      expect(find.text('0:00'), findsOneWidget);

      await _settle(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // AD-10 — un `Left` est un ÉTAT, jamais une levée.
  // ═════════════════════════════════════════════════════════════════════════
  group('AD-10 — échec typé', () {
    testWidgets('`load` rend Left ⇒ message d\'échec VISIBLE, aucun contrôle, '
        'aucune exception', (WidgetTester tester) async {
      final port = _FakeAudioPort(failLoad: true);
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(
          ZNoteAudioPlayer(
            source: const ZAudioSource.url('https://cdn.example/a.mp3'),
            port: port,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.text(kZNoteAudioDefaultLabels[kZNoteAudioFailedLabelKey]!),
        findsOneWidget,
      );
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(Slider), findsNothing);

      await _settle(tester);
    });

    testWidgets('`play` rend Left ⇒ bascule sur l\'état d\'échec, aucune levée',
        (WidgetTester tester) async {
      final port = _FakeAudioPort(failPlay: true);
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(
          ZNoteAudioPlayer(
            source: const ZAudioSource.url('https://cdn.example/a.mp3'),
            port: port,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.text(kZNoteAudioDefaultLabels[kZNoteAudioFailedLabelKey]!),
        findsOneWidget,
      );

      await _settle(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // AD-2 — granularité : la position ne reconstruit QUE l'horodatage.
  // ═════════════════════════════════════════════════════════════════════════
  group('AD-2 — rebuild granulaire sur le flux `position`', () {
    testWidgets(
        'un événement `position` change l\'horodatage SANS reconstruire le '
        'bouton ni le reste de la note (identité des widgets voisins)',
        (WidgetTester tester) async {
      final port = _FakeAudioPort();
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(ZSmartNoteReader(note: _noteWithUrl(), audioPort: port)),
      );
      await tester.pump();

      final IconButton buttonBefore =
          tester.widget<IconButton>(find.byType(IconButton));
      final ZMarkdownReader noteBefore =
          tester.widget<ZMarkdownReader>(find.byType(ZMarkdownReader));
      expect(find.text('0:00 / 1:00'), findsOneWidget);

      port.emitPosition(const Duration(seconds: 12));
      await tester.pump();

      // (a) la tranche qui devait bouger a bougé…
      expect(find.text('0:12 / 1:00'), findsOneWidget);
      expect(find.text('0:00 / 1:00'), findsNothing);
      // (b) …et RIEN d'autre n'a été reconstruit : les widgets voisins sont les
      //     MÊMES INSTANCES (un rebuild les aurait recréés).
      expect(
        identical(
          tester.widget<IconButton>(find.byType(IconButton)),
          buttonBefore,
        ),
        isTrue,
        reason: 'AD-2 : le bouton lecture/pause est hors du builder `position`.',
      );
      expect(
        identical(
          tester.widget<ZMarkdownReader>(find.byType(ZMarkdownReader)),
          noteBefore,
        ),
        isTrue,
        reason: 'AD-2 : le corps de la note ne se reconstruit pas au rythme du '
            'flux de position.',
      );

      await _settle(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // AD-13 — a11y
  // ═════════════════════════════════════════════════════════════════════════
  group('AD-13 — cible tactile et sémantique', () {
    // 🔴 PREMIÈRE VERSION DE CETTE GARDE : « la taille rendue est ≥ 48 dp »,
    //    thème par défaut. Elle NE ROUGISSAIT PAS quand on ramenait nos
    //    contraintes à 24 dp — parce que `MaterialTapTargetSize.padded` (le
    //    DÉFAUT du SDK) rembourre la cible à 48 dp quoi qu'on déclare. Elle
    //    mesurait donc le plancher du SDK, jamais le nôtre.
    //    ⇒ La mesure est faite sous `MaterialTapTargetSize.shrinkWrap`, où ce
    //      plancher DISPARAÎT : ce qui reste est exactement notre déclaration.
    testWidgets(
        'sous `shrinkWrap` (aucun rembourrage du SDK), le bouton mesure encore '
        'au moins 48 dp : la cible vient de NOS contraintes',
        (WidgetTester tester) async {
      final port = _FakeAudioPort();
      addTearDown(port.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: Scaffold(
              body: ZNoteAudioPlayer(
                source: const ZAudioSource.url('https://cdn.example/a.mp3'),
                port: port,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final Size size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));

      await _settle(tester);
    });

    testWidgets('et la cible reste ≥ 48 dp sous le thème par DÉFAUT',
        (WidgetTester tester) async {
      final port = _FakeAudioPort();
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(
          ZNoteAudioPlayer(
            source: const ZAudioSource.url('https://cdn.example/a.mp3'),
            port: port,
          ),
        ),
      );
      await tester.pump();

      final Size size = tester.getSize(find.byType(IconButton));
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));

      await _settle(tester);
    });

    testWidgets('libellés sémantiques résolus par l10n : défaut du paquet, '
        'puis bascule sur `pause` à l\'état `playing`',
        (WidgetTester tester) async {
      final port = _FakeAudioPort();
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(
          ZNoteAudioPlayer(
            source: const ZAudioSource.url('https://cdn.example/a.mp3'),
            port: port,
          ),
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel(
          kZNoteAudioDefaultLabels[kZNoteAudioPlayLabelKey]!,
        ),
        findsOneWidget,
      );

      port.emitState(ZAudioPlaybackState.playing);
      await tester.pump();

      expect(
        find.bySemanticsLabel(
          kZNoteAudioDefaultLabels[kZNoteAudioPauseLabelKey]!,
        ),
        findsOneWidget,
      );

      await _settle(tester);
    });

    testWidgets('`ZcrudScope(labels:)` SURCHARGE le libellé du paquet',
        (WidgetTester tester) async {
      final port = _FakeAudioPort();
      addTearDown(port.close);

      await tester.pumpWidget(
        _host(
          ZcrudScope(
            labels: ZcrudLabels(<String, String>{
              kZNoteAudioPlayLabelKey: 'Écouter',
            }),
            child: ZNoteAudioPlayer(
              source: const ZAudioSource.url('https://cdn.example/a.mp3'),
              port: port,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Écouter'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          kZNoteAudioDefaultLabels[kZNoteAudioPlayLabelKey]!,
        ),
        findsNothing,
      );

      await _settle(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Formatage neutre
  // ═════════════════════════════════════════════════════════════════════════
  group('zFormatNoteAudioTime — horodatage neutre', () {
    test('m:ss sous l\'heure, h:mm:ss au-delà, négatif ramené à zéro', () {
      expect(zFormatNoteAudioTime(Duration.zero), '0:00');
      expect(zFormatNoteAudioTime(const Duration(seconds: 9)), '0:09');
      expect(zFormatNoteAudioTime(const Duration(minutes: 12, seconds: 5)),
          '12:05');
      expect(
        zFormatNoteAudioTime(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
      expect(zFormatNoteAudioTime(const Duration(seconds: -5)), '0:00');
    });
  });
}
