// Cas d'or : le mixin `_$XxxZcrud` émis à la SIGNATURE DE LA BASE, quand la
// super-classe déclare déjà `toMap()`/`copyWith()` avec des paramètres que le
// schéma ne connaît pas (canaux hors codegen).
//
// Ce que ces gardes tiennent, et pourquoi :
//   1. COMPILATION — la fixture `audit_entry.dart` étend une base dont le
//      `toMap()` prend un paramètre nommé et dont le `copyWith()` couvre trois
//      canaux hors schéma. Un mixin émis à la seule vue du schéma serait refusé
//      (`invalid_override`) : la présence du fichier dans les imports est déjà
//      une assertion, et les gardes ci-dessous la doublent d'assertions de
//      SIGNATURE (tear-off typé) et de COMPORTEMENT.
//   2. SURCHARGE RÉELLE — le membre émis répond à un appel fait à travers le
//      type de base, ce qu'un membre d'extension ne fait jamais.
//   3. DÉLÉGATION — les canaux hors schéma ne sont pas réimplémentés : ils
//      viennent de la base et survivent à une copie qui ne les mentionne pas.
//   4. SENTINELLE — le corps émis ne nomme jamais la sentinelle de la base
//      (privée à sa bibliothèque). Un argument omis sur un appel fait à travers
//      le type de base reste un argument omis.
//   5. INERTIE — une base qui ne déclare rien, ou qui déclare sans paramètre
//      hors schéma, reçoit le mixin inchangé (ni clause `on`, ni `@override`).
@TestOn('vm')
library;

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_generator/src/zcrud_model_generator.dart';

import 'models/audit_base.dart';
import 'models/audit_entry.dart';

const _modelChecker =
    TypeChecker.typeNamed(ZcrudModel, inPackage: 'zcrud_annotations');

// Interpolés : ces sources n'existent qu'en mémoire (`gate:codegen` ne doit pas
// les prendre pour de vrais modèles réclamant un `.g.dart`).
const _model = '@ZcrudModel';
const _field = '@ZcrudField';

Future<String> _emitText(String source) => resolveSource(
      source,
      (resolver) async {
        final lib = await resolver
            .libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart'));
        final annotated = LibraryReader(lib).annotatedWith(_modelChecker).first;
        return const ZcrudModelGenerator()
            .generateForModel(annotated.element, annotated.annotation)
            .join('\n');
      },
      readAllSourcesFromFilesystem: true,
    );

/// Extrait le bloc `mixin _$…Zcrud … { … }` du texte émis.
String _mixinBlock(String emitted) {
  final start = emitted.indexOf('mixin _\$');
  expect(start, isNonNegative, reason: 'aucun mixin émis');
  final end = emitted.indexOf('\n}', start);
  expect(end, isNonNegative, reason: 'mixin non refermé');
  return emitted.substring(start, end + 2);
}

/// Base SANS `toMap`/`copyWith` — le mixin nominal convient.
const _plainBase = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

class PlainBase {
  const PlainBase();
}

$_model(kind: 'plain')
class Plain extends PlainBase {
  const Plain({required this.title});
  factory Plain.fromMap(Map<String, dynamic> map) => _\$PlainFromMap(map);
  $_field()
  final String title;
}
''';

/// Base qui déclare `toMap`/`copyWith` SANS paramètre hors schéma — le mixin
/// nominal les surcharge déjà sans conflit.
const _bareBase = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

abstract class BareBase {
  const BareBase();
  Map<String, dynamic> toMap();
  BareBase copyWith();
}

$_model(kind: 'bare')
class Bare extends BareBase with _\$BareZcrud {
  const Bare({required this.title});
  factory Bare.fromMap(Map<String, dynamic> map) => _\$BareFromMap(map);
  $_field()
  final String title;
}
''';

/// Base à canaux hors schéma — la forme qui impose l'alignement.
const _richBase = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

class Registry {
  const Registry();
}

class RichBase {
  const RichBase({this.source, required this.owner});
  final String? source;
  $_field()
  final String owner;
  Map<String, dynamic> toMap({Registry? registry}) => <String, dynamic>{};
  RichBase copyWith({Object? source}) => RichBase(source: source as String?);
}

$_model(kind: 'rich')
class Rich extends RichBase with _\$RichZcrud {
  const Rich({super.source, required super.owner, required this.title});
  factory Rich.fromMap(Map<String, dynamic> map) => _\$RichFromMap(map);
  $_field()
  final String title;
}
''';

/// Base dont le `toMap()` prend un paramètre POSITIONNEL — inaligneable.
const _positionalBase = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

class Registry {
  const Registry();
}

class PositionalBase {
  const PositionalBase();
  Map<String, dynamic> toMap([Registry? registry]) => <String, dynamic>{};
}

$_model(kind: 'positional')
class Positional extends PositionalBase with _\$PositionalZcrud {
  const Positional({required this.title});
  factory Positional.fromMap(Map<String, dynamic> map) =>
      _\$PositionalFromMap(map);
  $_field()
  final String title;
}
''';

/// Base dont un paramètre de `copyWith()` ne correspond à aucun accesseur : la
/// valeur courante du canal est inexprimable.
const _orphanParamBase = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

class OrphanBase {
  const OrphanBase();
  Map<String, dynamic> toMap({Object? registry}) => <String, dynamic>{};
  OrphanBase copyWith({Object? clearAll}) => const OrphanBase();
}

$_model(kind: 'orphan')
class Orphan extends OrphanBase with _\$OrphanZcrud {
  const Orphan({required this.title});
  factory Orphan.fromMap(Map<String, dynamic> map) => _\$OrphanFromMap(map);
  $_field()
  final String title;
}
''';

void main() {
  group('mixin aligné sur la base (canaux hors schéma)', () {
    test(
        'la signature émise est celle de la base — tear-off typé du `toMap` '
        'paramétré, et surcharge visible à travers le type de base', () {
      const entry = AuditEntry(action: 'open', label: 'L', source: 'sys');

      // Assertion de SIGNATURE : cette affectation ne compile que si le
      // `toMap()` d'instance accepte le paramètre nommé déclaré par la base.
      final Map<String, dynamic> Function({AuditRegistry? registry}) toMap =
          entry.toMap;
      expect(toMap(registry: const AuditRegistry('p:'))['source'], 'p:sys');

      // Assertion de SURCHARGE : l'appel passe par le type de BASE ; seul un
      // membre d'INSTANCE peut répondre — une extension serait invisible ici.
      final AuditBase base = entry;
      final map = base.toMap();
      expect(map['action'], 'open', reason: 'champ du schéma non émis');
      expect(map['count'], 0);
    });

    test(
        'les canaux hors schéma sont DÉLÉGUÉS à la base, jamais réimplémentés',
        () {
      const entry = AuditEntry(
        action: 'open',
        label: 'étiquette',
        extra: <String, dynamic>{'inconnu': 7},
        source: 'sys',
      );
      final map = entry.toMap();

      expect(map['label'], 'étiquette');
      expect(map['inconnu'], 7, reason: 'clé libre de `extra` perdue');
      expect(map['source'], 'sys');
      // Le schéma RECOUVRE la base : un canal libre ne peut pas écraser un
      // champ persisté.
      const collide = AuditEntry(
        action: 'open',
        extra: <String, dynamic>{'action': 'usurpé'},
      );
      expect(collide.toMap()['action'], 'open');
    });

    test(
        'un canal hors schéma non passé à `copyWith` n\'est PAS écrasé — y '
        'compris sur un appel fait à travers le type de base', () {
      const entry = AuditEntry(
        action: 'open',
        label: 'étiquette',
        extra: <String, dynamic>{'inconnu': 7},
        source: 'sys',
      );

      final copy = entry.copyWith(action: 'close');
      expect(copy.action, 'close');
      expect(copy.label, 'étiquette');
      expect(copy.extra['inconnu'], 7);
      expect(copy.source, 'sys');
      expect(copy.count, 0);

      // Le receveur est typé BASE : les défauts appliqués sont ceux de
      // l'implémentation réellement appelée (celle du mixin), donc la sentinelle
      // privée de la base n'est jamais nommée ni requise.
      final AuditBase base = entry;
      final throughBase = base.copyWith();
      expect(throughBase, isA<AuditEntry>());
      expect((throughBase as AuditEntry).action, 'open');
      expect(throughBase.label, 'étiquette');
      expect(throughBase.extra['inconnu'], 7);

      // `null` explicite reste distinct de « non fourni ».
      final cleared = base.copyWith(label: null);
      expect(cleared.label, isNull);
      expect((cleared as AuditEntry).action, 'open');
      expect(cleared.source, 'sys');
    });

    test('le texte émis reprend les paramètres de la base', () async {
      final mixin = _mixinBlock(await _emitText(_richBase));

      expect(mixin, contains('mixin _\$RichZcrud on RichBase {'));
      expect(mixin, contains('Map<String, dynamic> toMap({Registry? registry})'));
      expect(mixin, contains('...super.toMap(registry: registry),'));
      expect(mixin, contains('Object? source = _\$undefined,'));
      expect(
        mixin,
        contains('source: identical(source, _\$undefined) ? this.source : '
            'source as String?,'),
      );
      // Le champ du schéma que la base fournit déjà n'est pas redéclaré en
      // getter abstrait ; celui qui n'existe que sur le modèle l'est.
      expect(mixin, contains('String get title;'));
      expect(mixin, isNot(contains('String get owner;')),
          reason: 'champ du schéma déjà porté par la base : le mixin ne doit '
              'pas le redéclarer en getter abstrait');
    });
  });

  group('échecs de build EXPLICITES', () {
    test('paramètre POSITIONNEL sur la base : refusé, jamais émis en silence',
        () async {
      await expectLater(
        _emitText(_positionalBase),
        throwsA(isA<InvalidGenerationSourceError>().having(
          (e) => e.message,
          'message',
          allOf(contains('POSITIONNELS'), contains('Positional')),
        )),
      );
    });

    test(
        'paramètre de `copyWith()` sans accesseur sur la base : refusé, jamais '
        'émis en silence', () async {
      await expectLater(
        _emitText(_orphanParamBase),
        throwsA(isA<InvalidGenerationSourceError>().having(
          (e) => e.message,
          'message',
          allOf(contains('clearAll'), contains('aucun accesseur')),
        )),
      );
    });
  });

  group('inertie — le mixin nominal reste inchangé', () {
    test('base qui ne déclare rien : ni clause `on`, ni `@override`', () async {
      final mixin = _mixinBlock(await _emitText(_plainBase));

      expect(mixin, contains('mixin _\$PlainZcrud {'));
      expect(mixin, isNot(contains(' on ')));
      expect(mixin, isNot(contains('@override')));
      expect(mixin, isNot(contains('super.toMap(')));
      expect(mixin, contains('Map<String, dynamic> toMap() =>'));
    });

    test(
        'base qui déclare `toMap`/`copyWith` SANS paramètre hors schéma : '
        'inchangé aussi', () async {
      final mixin = _mixinBlock(await _emitText(_bareBase));

      expect(mixin, contains('mixin _\$BareZcrud {'));
      expect(mixin, isNot(contains('on BareBase')));
      expect(mixin, contains('Map<String, dynamic> toMap() =>'));
      expect(mixin, isNot(contains('super.toMap(')));
    });
  });
}
