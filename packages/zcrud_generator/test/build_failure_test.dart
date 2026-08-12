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
const _ignore = '@ZcrudIgnore';

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

  // =========================================================================
  // Champs NON ANNOTÉS — le silence est refusé quand il coûte des données.
  //
  // Seuls les champs annotés sont sérialisés. Un champ non annoté dont le type
  // n'est PAS sérialisable désigne un sous-objet métier : le laisser passer
  // l'effacerait du document à la première écriture, sans erreur de build ni
  // d'analyse. Le build le REFUSE et nomme les trois remèdes.
  //
  // Fixtures ISOLÉES : chacune est verte sur toutes les autres règles (décodeur
  // de domaine présent, signature compatible) ; seule la règle visée peut la
  // faire rougir. Le contre-témoin prouve que la règle DISCRIMINE.
  // =========================================================================
  group('champ non annoté de type non sérialisable → BUILD ROUGE', () {
    // Un sous-objet métier NON annoté `@ZcrudModel` : exactement le cas où une
    // sérialisation écrite à la main émettait le champ, et où le code généré
    // cesserait de l'émettre.
    const shape = '''
class GeoShape {
  const GeoShape({required this.wkt});
  final String wkt;
}
''';

    test('MORD : le champ est nommé, avec son type et les trois remèdes',
        () async {
      final src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$shape
$_model(kind: 'berth')
class Berth {
  const Berth({required this.title, this.location});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field()
  final String title;

  final GeoShape? location;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(title: map['title'] is String ? map['title'] as String : '');
''';
      await expectLater(
        _emitFirstModel(src),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('NON ANNOTÉ'),
              contains('location'),
              contains('GeoShape?'),
              contains('Berth'),
              contains('@ZcrudField'),
              contains('@ZcrudModel'),
              contains('@ZcrudIgnore'),
            ),
          ),
        ),
      );
    });

    test('tous les champs fautifs du modèle sont signalés en UNE passe',
        () async {
      final src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$shape
class Audit {
  const Audit();
}

$_model(kind: 'berth')
class Berth {
  const Berth({required this.title, this.location, this.audit});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field()
  final String title;

  final GeoShape? location;
  final Audit? audit;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(title: map['title'] is String ? map['title'] as String : '');
''';
      await expectLater(
        _emitFirstModel(src),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('2 champs NON ANNOTÉS'),
              contains('location'),
              contains('audit'),
            ),
          ),
        ),
      );
    });

    test('$_ignore : build VERT, et le champ reste ABSENT du code émis',
        () async {
      final src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$shape
$_model(kind: 'berth')
class Berth {
  const Berth({required this.title, this.location});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field()
  final String title;

  $_ignore()
  final GeoShape? location;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(title: map['title'] is String ? map['title'] as String : '');
''';
      final out = await _emitFirstModelText(src);
      // Le modèle est bien émis (la règle a été LEVÉE, pas contournée)…
      expect(out, contains('fromMap: Berth.fromMap,'));
      expect(out, contains("'title': this.title,"));
      // …et le champ exclu n'apparaît NULLE PART : ni `toMap`, ni décodeur, ni
      // schéma déclaratif, ni inventaire des clés persistées, ni `copyWith`.
      expect(out, isNot(contains('location')));
      expect(out, isNot(contains('GeoShape')));
    });

    test('CONTRE-TÉMOIN : un champ non annoté de type SÉRIALISABLE reste '
        'ignoré en silence (contrat inchangé)', () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model(kind: 'berth')
class Berth {
  const Berth({required this.title, this.draft = 0});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field()
  final String title;

  final int draft;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(title: map['title'] is String ? map['title'] as String : '');
''';
      final out = await _emitFirstModelText(src);
      expect(out, contains("'title': this.title,"));
      expect(out, isNot(contains('draft')));
    });

    test('un champ STATIQUE non annoté n\'a jamais été concerné', () async {
      final src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$shape
$_model(kind: 'berth')
class Berth {
  const Berth({required this.title});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  static const GeoShape origin = GeoShape(wkt: 'POINT(0 0)');

  $_field()
  final String title;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(title: map['title'] is String ? map['title'] as String : '');
''';
      expect(await _emitFirstModelText(src), contains('fromMap: Berth.fromMap,'));
    });

    test('EXEMPTION : un champ PRIVÉ non sérialisable ne rougit pas (bruit '
        'par construction : jamais persistable sous son propre nom)', () async {
      final src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$shape
$_model(kind: 'berth')
class Berth {
  const Berth({required this.title, GeoShape? cache}) : _cache = cache;

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field()
  final String title;

  final GeoShape? _cache;

  GeoShape? get cache => _cache;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(title: map['title'] is String ? map['title'] as String : '');
''';
      final out = await _emitFirstModelText(src);
      expect(out, contains('fromMap: Berth.fromMap,'));
      expect(out, isNot(contains('_cache')));
    });

    test('EXEMPTION AD-4 : `extension` / `extra` / backing privé d\'une classe '
        '`ZExtensible` ne réclament AUCUN marqueur', () async {
      final src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

$_model(kind: 'slots')
class Slots with ZExtensible {
  const Slots({
    required this.title,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  factory Slots.fromMap(Map<String, dynamic> map) {
    final base = _\$SlotsFromMap(map);
    return Slots(title: base.title, extra: map);
  }

  $_field()
  final String title;

  @override
  final ZExtension? extension;

  final Map<String, dynamic> _extra;

  @override
  Map<String, dynamic> get extra => _extra;
}

Slots _\$SlotsFromMap(Map<String, dynamic> map) =>
    Slots(title: map['title'] is String ? map['title'] as String : '');
''';
      final out = await _emitFirstModelText(src);
      // Build VERT : les slots AD-4 sont portés par le contrat d'architecture
      // (factory de domaine + garde d'extensibilité), pas par @ZcrudIgnore.
      expect(out, contains('fromMap: Slots.fromMap,'));
      // …et restent hors du schéma persisté : `title` est la SEULE clé émise.
      expect(
        out,
        contains("\$SlotsPersistedKeys = <String>{\n  'title',\n};"),
      );
      expect(out, isNot(contains("'extension'")));
      expect(out, isNot(contains("map['_extra']")));
    });

    test('CONTRE-TÉMOIN de l\'exemption AD-4 : un champ PUBLIC ordinaire d\'une '
        'classe `ZExtensible` rougit toujours', () async {
      final src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

$shape
$_model(kind: 'slots')
class Slots with ZExtensible {
  const Slots({
    required this.title,
    this.location,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  factory Slots.fromMap(Map<String, dynamic> map) {
    final base = _\$SlotsFromMap(map);
    return Slots(title: base.title, extra: map);
  }

  $_field()
  final String title;

  final GeoShape? location;

  @override
  ZExtension? get extension => null;

  final Map<String, dynamic> _extra;

  @override
  Map<String, dynamic> get extra => _extra;
}

Slots _\$SlotsFromMap(Map<String, dynamic> map) =>
    Slots(title: map['title'] is String ? map['title'] as String : '');
''';
      await expectLater(
        _emitFirstModel(src),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            allOf(contains('NON ANNOTÉ'), contains('location')),
          ),
        ),
      );
    });

    test('HÉRITAGE : un champ concret non sérialisable d\'une super-classe ou '
        'd\'un mixin rougit ; un champ privé hérité reste exempté', () async {
      final src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$shape
class BaseBerth {
  BaseBerth({this.location, GeoShape? cached}) : _cached = cached;

  final GeoShape? location;

  final GeoShape? _cached;

  GeoShape? get cached => _cached;
}

mixin Audited {
  GeoShape? auditShape;
}

$_model(kind: 'berth')
class Berth extends BaseBerth with Audited {
  Berth({required this.title, super.location});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field()
  final String title;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(title: map['title'] is String ? map['title'] as String : '');
''';
      await expectLater(
        _emitFirstModel(src),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('NON ANNOTÉ'),
              contains('location'),
              contains('auditShape'),
              isNot(contains('_cached')),
            ),
          ),
        ),
      );
    });
  });

  // =========================================================================
  // Enum redéclarant `name` comme membre d'instance : l'encodage émis passe
  // par `.name`, qui résoudrait sur le membre déclaré (libellé d'affichage) —
  // valeur écrite divergente du nom technique, illisible par le décodeur émis
  // (qui compare au nom technique via l'extension SDK, non masquable). Piège
  // SILENCIEUX à l'exécution → BUILD ROUGE explicite (AD-3).
  //
  // Fixtures ISOLÉES : vertes sur toutes les autres règles (décodeur de
  // domaine présent, types sérialisables) ; seule la règle visée peut les
  // faire rougir. Le contre-témoin (enhanced enum SANS masquage) prouve que la
  // règle DISCRIMINE.
  // =========================================================================
  group('enum redéclarant `name` → BUILD ROUGE', () {
    // Le motif exact du parc DODLP : libellé d'affichage porté par un CHAMP
    // `final String name`, alimenté par le constructeur.
    const maskedByField = '''
enum Provenance {
  dodlp('Agent DODLP'),
  iffd('Agent IFFD');
  const Provenance(this.name);
  final String name;
}
''';

    test('MORD (champ `final String name`) : champ et enum nommés, remèdes '
        'cités', () async {
      final src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$maskedByField
$_model(kind: 'berth')
class Berth {
  const Berth({required this.title, required this.provenance});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field()
  final String title;

  $_field()
  final Provenance provenance;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(title: '', provenance: Provenance.dodlp);
''';
      await expectLater(
        _emitFirstModel(src),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            allOf([
              contains('REDÉCLARE `name`'),
              contains('provenance'),
              contains('Provenance'),
              contains('MASQUE'),
              contains('EnumName.name'),
              contains('nom technique'),
              contains('label'),
              contains('@ZcrudIgnore'),
            ]),
          ),
        ),
      );
    });

    test('MORD aussi sur un GETTER `String get name`', () async {
      final src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

enum Statut {
  ouvert,
  clos;
  String get name => 'libellé';
}

$_model(kind: 'berth')
class Berth {
  const Berth({required this.statut});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field()
  final Statut statut;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(statut: Statut.ouvert);
''';
      await expectLater(
        _emitFirstModel(src),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            allOf(contains('statut'), contains('Statut'), contains('MASQUE')),
          ),
        ),
      );
    });

    test('MORD aussi en `List<EnumMasquant>`', () async {
      final src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$maskedByField
$_model(kind: 'berth')
class Berth {
  const Berth({this.sources = const <Provenance>[]});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field()
  final List<Provenance> sources;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) => const Berth();
''';
      await expectLater(
        _emitFirstModel(src),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            allOf(contains('sources'), contains('Provenance')),
          ),
        ),
      );
    });

    test('tous les champs fautifs du modèle sont signalés en UNE passe',
        () async {
      final src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$maskedByField
$_model(kind: 'berth')
class Berth {
  const Berth({
    required this.provenance,
    this.sources = const <Provenance>[],
  });

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field()
  final Provenance provenance;

  $_field()
  final List<Provenance> sources;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(provenance: Provenance.dodlp);
''';
      await expectLater(
        _emitFirstModel(src),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('2 champs enum'),
              contains('provenance'),
              contains('sources'),
            ),
          ),
        ),
      );
    });

    test('CONTRE-TÉMOIN : enhanced enum SANS masquage (constructeur + champ '
        '`label`) → build VERT, `.name` technique émis', () async {
      const src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

enum Grade {
  bas('Grade bas'),
  haut('Grade haut');
  const Grade(this.label);
  final String label;
}

$_model(kind: 'berth')
class Berth {
  const Berth({required this.grade});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field()
  final Grade grade;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) => Berth(grade: Grade.bas);
''';
      final out = await _emitFirstModelText(src);
      // Encodage par `.name` : sans masquage, c'est le nom technique.
      expect(out, contains("'grade': this.grade.name,"));
      // Décodage symétrique par le nom technique.
      expect(out, contains(r'_$enumFromName(Grade.values, ' "map['grade'])"));
    });
  });

  // =========================================================================
  // `@ZcrudIgnore` combiné à une annotation de sérialisation : les deux
  // déclarations se CONTREDISENT — l'une exclut le champ de la persistance,
  // l'autre l'y inscrit. Résoudre en silence (dans un sens comme dans l'autre)
  // écrirait ou perdrait une donnée à l'insu de l'auteur : échec de build
  // explicite (AD-3), au même niveau que la collision de clé persistée.
  // =========================================================================
  group('$_ignore + annotation de sérialisation → BUILD ROUGE', () {
    test('$_ignore + $_field sur le même champ → InvalidGenerationSourceError',
        () async {
      final src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model(kind: 'berth')
class Berth {
  const Berth({required this.title, this.note});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  $_field()
  final String title;

  $_field()
  $_ignore()
  final String? note;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(title: map['title'] is String ? map['title'] as String : '');
''';
      await expectLater(
        _emitFirstModel(src),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('note'),
              contains('@ZcrudIgnore'),
              contains('CONTREDISENT'),
            ),
          ),
        ),
      );
    });

    test('$_ignore + @ZcrudId sur le même champ → InvalidGenerationSourceError',
        () async {
      final src = '''
import 'package:zcrud_annotations/zcrud_annotations.dart';

$_model(kind: 'berth')
class Berth {
  const Berth({this.id, required this.title});

  factory Berth.fromMap(Map<String, dynamic> map) => _\$BerthFromMap(map);

  @ZcrudId()
  $_ignore()
  final String? id;

  $_field()
  final String title;
}

Berth _\$BerthFromMap(Map<String, dynamic> map) =>
    Berth(title: map['title'] is String ? map['title'] as String : '');
''';
      await expectLater(
        _emitFirstModel(src),
        throwsA(
          isA<InvalidGenerationSourceError>().having(
            (e) => e.message,
            'message',
            allOf(contains('id'), contains('CONTREDISENT')),
          ),
        ),
      );
    });
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

  // Slot AD-4 d'une classe `ZExtensible` : EXEMPTÉ du contrôle de perte
  // silencieuse (le contrat de factory de domaine et le garde d'extensibilité
  // couvrent déjà ce canal) — aucun marqueur requis.
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
