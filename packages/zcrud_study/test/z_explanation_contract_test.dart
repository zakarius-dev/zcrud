// Lot P1-D — contrat PROGRESSIF de l'explication IA.
//
// Ce fichier garde (1) la forme EXACTE du nouveau contrat (flux NU, avancement
// cumulatif, port inerte), et (2) l'INERTIE ABSOLUE du site existant
// `ZAiExplanationRequest`/`ZAiExplanationPort` : les trois champs additifs
// (`style`, `operation`, `routeId`) valent `null` par défaut, et une requête
// construite comme avant le lot est EXACTEMENT la même valeur qu'avant.
//
// Runner R14 : `flutter test`. Aucun accès disque ici (le gate `web` compile
// ce fichier vers Node sans peine).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Port progressif app-side : rejoue une liste d'événements figée.
class _FakeStreamPort implements ZAiExplanationStreamPort {
  _FakeStreamPort(this._events);

  final List<ZResult<ZGenerationProgress>> _events;

  @override
  bool get isAvailable => true;

  @override
  Stream<ZResult<ZGenerationProgress>> explainStream(
    ZAiExplanationRequest request,
  ) =>
      Stream<ZResult<ZGenerationProgress>>.fromIterable(_events);
}

void main() {
  group('ZGenerationProgress — valeur, texte CUMULATIF', () {
    test('égalité PAR VALEUR et défaut isDone=false', () {
      const a = ZGenerationProgress(text: 'ab');
      const b = ZGenerationProgress(text: 'ab');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.isDone, isFalse);
      expect(
        a,
        isNot(equals(const ZGenerationProgress(text: 'ab', isDone: true))),
      );
      expect(a, isNot(equals(const ZGenerationProgress(text: 'abc'))));
    });
  });

  group('ZAiExplanationStreamPort — flux NU, jamais un Future', () {
    test('explainStream ⇒ Stream<ZResult<ZGenerationProgress>> exact',
        () async {
      // Liaison de type statique EXACTE : rougirait à la COMPILATION si la
      // signature devenait `Future<...>` ou un flux de `String` nue.
      final ZAiExplanationStreamPort port = _FakeStreamPort(
        <ZResult<ZGenerationProgress>>[
          Right<ZFailure, ZGenerationProgress>(
            const ZGenerationProgress(text: 'a'),
          ),
          Right<ZFailure, ZGenerationProgress>(
            const ZGenerationProgress(text: 'ab', isDone: true),
          ),
        ],
      );
      final Stream<ZResult<ZGenerationProgress>> stream =
          port.explainStream(const ZAiExplanationRequest(content: 'x'));
      final events = await stream.toList();
      expect(events, hasLength(2));
      expect(
        events.last.getOrElse(() => const ZGenerationProgress(text: '!')),
        equals(const ZGenerationProgress(text: 'ab', isDone: true)),
      );
    });

    test('port INERTE : indisponible et flux vide qui se termine', () async {
      const ZAiExplanationStreamPort port = ZInertAiExplanationStreamPort();
      expect(port.isAvailable, isFalse);
      final events = await port
          .explainStream(const ZAiExplanationRequest(content: 'x'))
          .toList();
      expect(events, isEmpty);
    });
  });

  group('INERTIE du site existant — ZAiExplanationRequest', () {
    test('les trois champs additifs valent null par défaut', () {
      const request = ZAiExplanationRequest(content: 'x');
      expect(request.style, isNull);
      expect(request.operation, isNull);
      expect(request.routeId, isNull);
    });

    test('égalité INCHANGÉE pour une requête construite comme avant le lot',
        () {
      const a = ZAiExplanationRequest(
        content: 'x',
        context: 'c',
        languageTag: 'fr',
      );
      const b = ZAiExplanationRequest(
        content: 'x',
        context: 'c',
        languageTag: 'fr',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('les champs additifs DISCRIMINENT l\'égalité', () {
      const base = ZAiExplanationRequest(content: 'x');
      expect(
        base,
        isNot(equals(const ZAiExplanationRequest(content: 'x', style: 's'))),
      );
      expect(
        base,
        isNot(
          equals(const ZAiExplanationRequest(content: 'x', operation: 'o')),
        ),
      );
      expect(
        base,
        isNot(equals(const ZAiExplanationRequest(content: 'x', routeId: 'r'))),
      );
    });

    test('extra reste sanitisé des clés réservées (AD-19.1, inchangé)', () {
      const request = ZAiExplanationRequest(
        content: 'x',
        extra: <String, dynamic>{'updated_at': 1, 'is_deleted': true, 'k': 'v'},
      );
      expect(request.extra, equals(<String, dynamic>{'k': 'v'}));
    });

    test('withOperation : opération posée, TOUT le reste préservé', () {
      const base = ZAiExplanationRequest(
        content: 'sujet',
        context: 'ctx',
        languageTag: 'fr',
        style: 'styleInitial',
        routeId: 'route',
        extra: <String, dynamic>{'k': 'v'},
      );
      final derived = base.withOperation('op');
      expect(derived.operation, 'op');
      expect(derived.content, 'sujet');
      expect(derived.context, 'ctx');
      expect(derived.languageTag, 'fr');
      expect(derived.style, 'styleInitial');
      expect(derived.routeId, 'route');
      expect(derived.extra, equals(<String, dynamic>{'k': 'v'}));
    });

    test('withOperation : style et contenu substitués quand fournis', () {
      const base = ZAiExplanationRequest(content: 'sujet', style: 'a');
      final derived =
          base.withOperation('op', style: 'b', content: 'texte courant');
      expect(derived.operation, 'op');
      expect(derived.style, 'b');
      expect(derived.content, 'texte courant');
    });

    test('withRouteId : route posée (null compris), reste inchangé', () {
      const base = ZAiExplanationRequest(content: 'x', routeId: 'r1');
      expect(base.withRouteId('r2').routeId, 'r2');
      expect(base.withRouteId(null).routeId, isNull);
      expect(base.withRouteId('r2').content, 'x');
    });
  });
}
