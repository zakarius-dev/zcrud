// AC3/AC7 — catalogue devise : chargement PARESSEUX + cache + dé-dup concurrent,
// injectable, parse DÉFENSIF (asset absent / JSON malformé → vide), byCode/search.
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
[
  {"code":"XOF","name":"Franc CFA","symbol":"CFA","decimalDigits":0},
  {"code":"EUR","name":"Euro","symbol":"€","decimalDigits":2}
]''';

void main() {
  group('AC3 — paresse + cache', () {
    test('load() ne lit l\'asset qu\'une seule fois (cache)', () async {
      final bundle = _FakeBundle(_json);
      final cat = ZCurrencyCatalog(bundle: bundle);
      expect(cat.isLoaded, isFalse);
      expect(bundle.stringLoads, 0);
      final first = await cat.load();
      expect(first, hasLength(2));
      expect(bundle.stringLoads, 1);
      await cat.load();
      expect(bundle.stringLoads, 1);
      expect(cat.assetReads, 1);
    });

    test('MEDIUM-1 : 2 load() concurrents → un seul parse', () async {
      final bundle = _FakeBundle(_json);
      final cat = ZCurrencyCatalog(bundle: bundle);
      final f1 = cat.load();
      final f2 = cat.load();
      expect(identical(f1, f2), isTrue);
      final r1 = await f1;
      final r2 = await f2;
      expect(identical(r1, r2), isTrue);
      expect(bundle.stringLoads, 1);
      expect(cat.assetReads, 1);
    });
  });

  group('LOW-1 — catalogue devise partagé', () {
    test('sharedDefaultCurrencyCatalog() stable', () {
      expect(identical(sharedDefaultCurrencyCatalog(),
          sharedDefaultCurrencyCatalog()), isTrue);
    });

    test('byCode + search', () async {
      final cat = ZCurrencyCatalog(bundle: _FakeBundle(_json));
      await cat.load();
      expect(cat.byCode('xof')?.name, 'Franc CFA');
      expect(cat.byCode('ZZZ'), isNull);
      expect(cat.search('euro').single.code, 'EUR');
      expect(cat.search('CFA').single.code, 'XOF');
      expect(cat.search(''), hasLength(2));
    });
  });

  group('AC3 — injectable fromList (sans disque)', () {
    test('fromList pré-chargé : aucune lecture d\'asset', () async {
      final cat = ZCurrencyCatalog.fromList(const <ZCurrencyInfo>[
        ZCurrencyInfo(code: 'XOF', name: 'Franc CFA', decimalDigits: 0),
      ]);
      final list = await cat.load();
      expect(list, hasLength(1));
      expect(cat.assetReads, 0);
      expect(cat.byCode('XOF')?.decimalDigits, 0);
    });
  });

  group('AC3/AC7 — défensif : asset absent / malformé → vide', () {
    test('asset introuvable → vide, jamais de throw', () async {
      final cat = ZCurrencyCatalog(bundle: _FakeBundle.missing());
      late List<ZCurrencyInfo> list;
      await expectLater(() async => list = await cat.load(), returnsNormally);
      expect(list, isEmpty);
      expect(cat.isLoaded, isTrue);
    });

    test('JSON malformé / non-liste → vide', () async {
      expect(await ZCurrencyCatalog(bundle: _FakeBundle('{ nope [')).load(),
          isEmpty);
      expect(await ZCurrencyCatalog(bundle: _FakeBundle('{"code":"EUR"}')).load(),
          isEmpty);
    });

    test('entrées non conformes ignorées', () async {
      final cat = ZCurrencyCatalog(
          bundle: _FakeBundle('[{"name":"sans code"},{"code":"EUR"},7]'));
      final list = await cat.load();
      expect(list, hasLength(1));
      expect(list.single.code, 'EUR');
    });

    test('search/byCode avant load → vide/null', () {
      final cat = ZCurrencyCatalog(bundle: _FakeBundle(_json));
      expect(cat.search('x'), isEmpty);
      expect(cat.byCode('EUR'), isNull);
    });
  });

  group('asset réel bundlé', () {
    testWidgets('currencies.json bundlé charge un catalogue non trivial',
        (tester) async {
      final cat = ZCurrencyCatalog(assetPath: 'lib/assets/currencies.json');
      final list = await cat.load();
      expect(list.length, greaterThan(30));
      expect(cat.byCode('XOF')?.symbol, 'CFA');
      expect(cat.byCode('EUR')?.decimalDigits, 2);
    });
  });
}
