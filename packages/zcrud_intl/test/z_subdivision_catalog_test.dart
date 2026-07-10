// AC5/AC7 — catalogue subdivisions (indexé par pays) : paresse + cache + dé-dup,
// injectable, parse DÉFENSIF, forCountry/hasCountry/byCode.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

class _FakeBundle extends AssetBundle {
  _FakeBundle(this._content);
  _FakeBundle.missing() : _content = null;

  final String? _content;
  int stringLoads = 0;

  @override
  Future<ByteData> load(String key) async =>
      throw UnimplementedError('load non utilisé');

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    stringLoads++;
    final c = _content;
    if (c == null) throw Exception('asset introuvable: $key');
    return c;
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) =>
      throw UnimplementedError('loadStructuredData non utilisé');
}

const _json = '''
{
  "NE": [ {"code":"NE-2","name":"Diffa","type":"region"},
          {"code":"NE-8","name":"Niamey"} ],
  "US": [ {"code":"US-CA","name":"California","type":"state"} ]
}''';

void main() {
  group('AC5 — paresse + cache + concurrent', () {
    test('load() ne lit l\'asset qu\'une fois', () async {
      final bundle = _FakeBundle(_json);
      final cat = ZSubdivisionCatalog(bundle: bundle);
      expect(cat.isLoaded, isFalse);
      expect(bundle.stringLoads, 0);
      await cat.load();
      expect(bundle.stringLoads, 1);
      await cat.load();
      expect(bundle.stringLoads, 1);
    });

    test('2 load() concurrents → un seul parse', () async {
      final bundle = _FakeBundle(_json);
      final cat = ZSubdivisionCatalog(bundle: bundle);
      final f1 = cat.load();
      final f2 = cat.load();
      expect(identical(f1, f2), isTrue);
      await f1;
      await f2;
      expect(cat.assetReads, 1);
    });
  });

  group('AC5 — forCountry dépendant du pays', () {
    test('forCountry indexé + insensible casse ; countryIso du bucket propagé',
        () async {
      final cat = ZSubdivisionCatalog(bundle: _FakeBundle(_json));
      await cat.load();
      final ne = cat.forCountry('ne');
      expect(ne, hasLength(2));
      expect(ne.first.code, 'NE-2');
      expect(ne.first.countryIso, 'NE'); // repli bucket
      expect(cat.forCountry('US').single.name, 'California');
      expect(cat.hasCountry('NE'), isTrue);
      expect(cat.byCode('NE', 'ne-2')?.name, 'Diffa');
    });

    test('pays inconnu "ZZ" → liste vide (jamais de throw)', () async {
      final cat = ZSubdivisionCatalog(bundle: _FakeBundle(_json));
      await cat.load();
      expect(cat.forCountry('ZZ'), isEmpty);
      expect(cat.hasCountry('ZZ'), isFalse);
      expect(cat.byCode('ZZ', 'ZZ-99'), isNull);
    });

    test('forCountry avant load → vide', () {
      final cat = ZSubdivisionCatalog(bundle: _FakeBundle(_json));
      expect(cat.forCountry('NE'), isEmpty);
    });
  });

  group('AC5 — injectable fromMap', () {
    test('fromMap pré-chargé : aucune lecture d\'asset', () async {
      final cat = ZSubdivisionCatalog.fromMap(<String, List<ZSubdivision>>{
        'NE': const <ZSubdivision>[
          ZSubdivision(code: 'NE-2', countryIso: 'NE', name: 'Diffa'),
        ],
      });
      await cat.load();
      expect(cat.assetReads, 0);
      expect(cat.forCountry('NE').single.name, 'Diffa');
    });

    test('sharedDefaultSubdivisionCatalog() stable', () {
      expect(identical(sharedDefaultSubdivisionCatalog(),
          sharedDefaultSubdivisionCatalog()), isTrue);
    });
  });

  group('AC7 — défensif : asset absent / malformé → vide', () {
    test('asset introuvable → vide, jamais de throw', () async {
      final cat = ZSubdivisionCatalog(bundle: _FakeBundle.missing());
      await expectLater(cat.load(), completes);
      expect(cat.forCountry('NE'), isEmpty);
      expect(cat.isLoaded, isTrue);
    });

    test('JSON malformé / non-objet → vide', () async {
      await ZSubdivisionCatalog(bundle: _FakeBundle('[ nope')).load();
      final cat2 = ZSubdivisionCatalog(bundle: _FakeBundle('[1,2,3]'));
      await cat2.load();
      expect(cat2.forCountry('NE'), isEmpty);
    });

    test('buckets non-listes ou entrées non conformes ignorés', () async {
      final cat = ZSubdivisionCatalog(bundle: _FakeBundle(
          '{"NE":"pas une liste","US":[{"nope":1},{"code":"US-CA"},9]}'));
      await cat.load();
      expect(cat.forCountry('NE'), isEmpty);
      expect(cat.forCountry('US').single.code, 'US-CA');
    });
  });

  group('asset réel bundlé', () {
    testWidgets('subdivisions.json bundlé : NE non trivial',
        (tester) async {
      final cat =
          ZSubdivisionCatalog(assetPath: 'lib/assets/subdivisions.json');
      await cat.load();
      expect(cat.forCountry('NE').length, greaterThanOrEqualTo(8));
      expect(cat.byCode('NE', 'NE-2')?.name, 'Diffa');
      expect(cat.forCountry('US'), isNotEmpty);
    });
  });
}
