// AC9 (AD-3) : échec de build EXPLICITE (`InvalidGenerationSourceError`, message
// actionnable) — jamais un cast `null` silencieux. Le cœur d'émission
// (`generateForModel`) est piloté DIRECTEMENT sur une source résolue en mémoire
// (`resolveSource`), sans pipeline build_runner ni fichier disque (donc
// invisible pour `gate:codegen`).
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_generator/src/zcrud_model_generator.dart';

const _modelChecker =
    TypeChecker.typeNamed(ZcrudModel, inPackage: 'zcrud_annotations');

// Les annotations sont interpolées (jamais `@ZcrudModel` en début de ligne dans
// CE fichier) : ces sources n'existent qu'en mémoire, `gate:codegen` ne doit
// donc pas les prendre pour de vrais modèles réclamant un `.g.dart`.
const _model = '@ZcrudModel';
const _field = '@ZcrudField';

/// Résout [source] et émet le premier modèle `@ZcrudModel` via le générateur
/// (lève si le type de champ / la clé est invalide).
Future<void> _emitFirstModel(String source) => resolveSource(
      source,
      (resolver) async {
        final lib = await resolver
            .libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart'));
        final annotated =
            LibraryReader(lib).annotatedWith(_modelChecker).first;
        const ZcrudModelGenerator()
            .generateForModel(annotated.element, annotated.annotation)
            // Force l'évaluation (Iterable paresseux).
            .toList();
      },
      readAllSourcesFromFilesystem: true,
    );

/// Résout [source] et retourne le TEXTE émis pour le premier `@ZcrudModel`.
Future<String> _emitFirstModelText(String source) => resolveSource(
      source,
      (resolver) async {
        final lib = await resolver
            .libraryFor(AssetId('_resolve_source', 'lib/_resolve_source.dart'));
        final annotated =
            LibraryReader(lib).annotatedWith(_modelChecker).first;
        return const ZcrudModelGenerator()
            .generateForModel(annotated.element, annotated.annotation)
            .join('\n');
      },
      readAllSourcesFromFilesystem: true,
    );

void main() {
  test('type de champ non (dé)sérialisable → InvalidGenerationSourceError', () {
    const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model()
class BadType {
  const BadType({required this.link});

  $_field()
  final Uri link;
}
''';
    expect(
      () => _emitFirstModel(src),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });

  test('collision de clé persistée → InvalidGenerationSourceError', () {
    const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model()
class DupKey {
  const DupKey({required this.a, required this.b});

  $_field(name: 'k')
  final String a;

  $_field(name: 'k')
  final String b;
}
''';
    expect(
      () => _emitFirstModel(src),
      throwsA(isA<InvalidGenerationSourceError>()),
    );
  });

  // -------------------------------------------------------------------------
  // DW-ES14-1 / AD-4 (AC2) : la factory de DOMAINE `Xxx.fromMap` est un CONTRAT
  // vérifié par machine. Son absence (ou une signature incompatible) est un
  // ÉCHEC DE BUILD EXPLICITE — **jamais** un repli silencieux sur
  // `_$XxxFromMap`, qui recréerait le défaut corrigé (destruction d'`extra` sur
  // la voie `registry.decode`). R6 : aucune dégradation silencieuse.
  // -------------------------------------------------------------------------
  group('DW-ES14-1 — factory de domaine `fromMap` obligatoire (AC2)', () {
    test('classe SANS `fromMap` → InvalidGenerationSourceError (jamais de repli)',
        () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model()
class NoFromMap {
  const NoFromMap({required this.title});

  $_field()
  final String title;
}
''';
      await expectLater(
        _emitFirstModel(src),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('NoFromMap'),
              contains('DW-ES14-1'),
              contains('extra'),
              contains('factory NoFromMap.fromMap'),
            ),
          ),
        ),
      );
    });

    test('`fromMap` avec un paramètre REQUIS surnuméraire → échec explicite',
        () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model()
class BadFromMap {
  const BadFromMap({required this.title});

  factory BadFromMap.fromMap(
    Map<String, dynamic> map, {
    required String tenant,
  }) =>
      BadFromMap(title: '\$tenant');

  $_field()
  final String title;
}
''';
      await expectLater(
        _emitFirstModel(src),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('BadFromMap.fromMap'),
              contains('INCOMPATIBLE'),
              contains('DW-ES14-1'),
            ),
          ),
        ),
      );
    });

    test('`fromMap` à paramètres nommés OPTIONNELS → ACCEPTÉE (patron ZFlashcard)',
        () async {
      // ⚠️ H1 (code-review ES-2.0) : la v1 de cette fixture acceptait un
      // `OkModel.fromMap` qui IGNORAIT complètement `map`
      // (`=> OkModel(title: tenant ?? '')`). L'exemple de RÉFÉRENCE du contrat
      // était donc une factory qui ne décodait RIEN — le contrat certifiait son
      // propre contre-exemple. La fixture décode désormais réellement `map`.
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model(kind: 'ok_model')
class OkModel {
  const OkModel({required this.title});

  factory OkModel.fromMap(
    Map<String, dynamic> map, {
    String? tenant,
  }) =>
      _\$OkModelFromMap(map);

  $_field()
  final String title;
}

// Stub du symbole que le codegen émettrait (la source n'est résolue qu'en
// mémoire : le `part` n'existe pas ici).
OkModel _\$OkModelFromMap(Map<String, dynamic> map) =>
    OkModel(title: map['title'] is String ? map['title'] as String : '');
''';
      final out = await _emitFirstModelText(src);
      // AC1 : le registrar émis décode par la factory de DOMAINE.
      expect(out, contains('fromMap: OkModel.fromMap,'));
      expect(out, isNot(contains(r'fromMap: _$OkModelFromMap,')));
      // `OkModel` n'est PAS `ZExtensible` : aucun garde runtime à poser, et la
      // délégation nue à `_$OkModelFromMap` est ici parfaitement LÉGITIME.
      expect(out, isNot(contains(r'_$zRequireExtraPreserved<OkModel>')));
    });

    // -----------------------------------------------------------------------
    // M1 — la signature est jugée sur les TYPES (TypeSystem), plus sur la CHAÎNE
    // d'affichage. La v1 (`getDisplayString() == 'Map<String, dynamic>'`)
    // REJETAIT — échec de build — des décodeurs légaux et ASSIGNABLES.
    // -----------------------------------------------------------------------
    test('M1 : `Map<String, Object?>` → ACCEPTÉE (mutuellement sous-type)',
        () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model(kind: 'objq')
class ObjQ {
  const ObjQ({required this.title});

  factory ObjQ.fromMap(Map<String, Object?> map) => _\$ObjQFromMap(map);

  $_field()
  final String title;
}

ObjQ _\$ObjQFromMap(Map<String, Object?> map) =>
    ObjQ(title: map['title'] is String ? map['title']! as String : '');
''';
      expect(await _emitFirstModelText(src), contains('fromMap: ObjQ.fromMap,'));
    });

    test('M1 : typedef alias de `Map<String, dynamic>` → ACCEPTÉE', () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

typedef JsonMap = Map<String, dynamic>;

$_model(kind: 'aliased')
class Aliased {
  const Aliased({required this.title});

  factory Aliased.fromMap(JsonMap map) => _\$AliasedFromMap(map);

  $_field()
  final String title;
}

Aliased _\$AliasedFromMap(JsonMap map) =>
    Aliased(title: map['title'] is String ? map['title'] as String : '');
''';
      expect(
        await _emitFirstModelText(src),
        contains('fromMap: Aliased.fromMap,'),
      );
    });

    // -----------------------------------------------------------------------
    // M2 — un `fromMap` STATIQUE est un tear-off valide : il est ACCEPTÉ. La v1
    // n'inspectait que `element.constructors` et affirmait « ne déclare AUCUNE
    // factory fromMap » — message FAUX.
    // -----------------------------------------------------------------------
    test('M2 : `static fromMap` (tear-off valide) → ACCEPTÉE', () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model(kind: 'statique')
class Statique {
  const Statique({required this.title});

  static Statique fromMap(Map<String, dynamic> map) => _\$StatiqueFromMap(map);

  $_field()
  final String title;
}

Statique _\$StatiqueFromMap(Map<String, dynamic> map) =>
    Statique(title: map['title'] is String ? map['title'] as String : '');
''';
      expect(
        await _emitFirstModelText(src),
        contains('fromMap: Statique.fromMap,'),
      );
    });
  });

  // =========================================================================
  // 🔴 H1 — la DÉLÉGATION NUE à `_$XxxFromMap` sur une classe `ZExtensible` est
  // un ÉCHEC DE BUILD.
  //
  // C'est *littéralement* le geste que l'ancien message d'erreur PRESCRIVAIT :
  // contrat satisfait, build vert, `extra` détruit — DW-ES14-1 recréé. Le gate
  // qui interdit la dette enseignait la dette.
  //
  // ⚠️ R2 — fixtures ISOLÉES : chacune est VERTE sur toutes les autres règles
  // (signature compatible, décodeur présent) ; SEULE la règle visée peut la
  // faire rougir. Et le contre-témoin (`ExtensibleOk`) prouve que la règle
  // DISCRIMINE au lieu de rougir sur tout ce qui est `ZExtensible`.
  // =========================================================================
  group('H1 — `ZExtensible` + délégation nue à `_\$XxxFromMap` → BUILD ROUGE', () {
    // Base `ZExtensible` INDIRECTE : prouve que la détection résout la hiérarchie
    // TRANSITIVEMENT (cf. M4 — le motif `class ZSmartNote extends ZBaseStudyEntity`
    // qu'ES-2 va multiplier), pas seulement le `with ZExtensible` cité en propre.
    const preamble = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

abstract class BaseStudy with ZExtensible {
  const BaseStudy();
  @override
  ZExtension? get extension => null;
}
''';

    test('MORD : `ZExtensible` TRANSITIF + `=> _\$XxxFromMap(map)` nu', () async {
      final src = '''
$preamble
$_model(kind: 'naked')
class Naked extends BaseStudy {
  const Naked({required this.title});

  factory Naked.fromMap(Map<String, dynamic> map) => _\$NakedFromMap(map);

  $_field()
  final String title;

  @override
  Map<String, dynamic> get extra => const <String, dynamic>{};
}

Naked _\$NakedFromMap(Map<String, dynamic> map) =>
    Naked(title: map['title'] is String ? map['title'] as String : '');
''';
      await expectLater(
        _emitFirstModel(src),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Naked.fromMap'),
              contains('DÉLÈGUE NUEMENT'),
              contains('DW-ES14-1'),
              // Le message PRESCRIT désormais la forme QUI MARCHE…
              contains('extra: _extraFrom(map)'),
              // …et JAMAIS la forme impotente qu'il dictait avant.
              isNot(contains(r'factory Naked.fromMap(Map<String, dynamic> map) '
                  r'=> _$NakedFromMap(map);')),
            ),
          ),
        ),
      );
    });

    test('MORD aussi sur le bloc `{ return _\$XxxFromMap(map); }`', () async {
      final src = '''
$preamble
$_model(kind: 'naked_block')
class NakedBlock extends BaseStudy {
  const NakedBlock({required this.title});

  factory NakedBlock.fromMap(Map<String, dynamic> map) {
    return _\$NakedBlockFromMap(map);
  }

  $_field()
  final String title;

  @override
  Map<String, dynamic> get extra => const <String, dynamic>{};
}

NakedBlock _\$NakedBlockFromMap(Map<String, dynamic> map) =>
    NakedBlock(title: map['title'] is String ? map['title'] as String : '');
''';
      await expectLater(
        _emitFirstModel(src),
        throwsA(isA<InvalidGenerationSourceError>()),
      );
    });

    test('CONTRE-TÉMOIN : `ZExtensible` + factory qui peuple `extra` → ACCEPTÉE',
        () async {
      final src = '''
$preamble
$_model(kind: 'ext_ok')
class ExtensibleOk extends BaseStudy {
  const ExtensibleOk({required this.title, this.extra = const <String, dynamic>{}});

  factory ExtensibleOk.fromMap(Map<String, dynamic> map) {
    final base = _\$ExtensibleOkFromMap(map);
    return ExtensibleOk(title: base.title, extra: map);
  }

  $_field()
  final String title;

  @override
  final Map<String, dynamic> extra;
}

ExtensibleOk _\$ExtensibleOkFromMap(Map<String, dynamic> map) =>
    ExtensibleOk(title: map['title'] is String ? map['title'] as String : '');
''';
      final out = await _emitFirstModelText(src);
      expect(out, contains('fromMap: ExtensibleOk.fromMap,'));
      // …et le GARDE RUNTIME est posé (c'est lui qui observera le POUVOIR).
      expect(out, contains(r'_$zRequireExtraPreserved<ExtensibleOk>'));
    });

    test('NON-`ZExtensible` : la délégation nue reste LÉGITIME (pas de faux rouge)',
        () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model(kind: 'plain')
class Plain {
  const Plain({required this.title});

  factory Plain.fromMap(Map<String, dynamic> map) => _\$PlainFromMap(map);

  $_field()
  final String title;
}

Plain _\$PlainFromMap(Map<String, dynamic> map) =>
    Plain(title: map['title'] is String ? map['title'] as String : '');
''';
      // `ZChoice` est exactement ce cas : aucun slot `extra` à préserver.
      expect(await _emitFirstModelText(src), contains('fromMap: Plain.fromMap,'));
    });
  });
}
