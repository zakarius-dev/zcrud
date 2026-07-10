// AC4/AC5/AC11 — catalogue pays : chargement PARESSEUX + cache, injectable,
// parse DÉFENSIF (asset absent / JSON malformé → vide), recherche/lookup.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

/// Bundle de test : compte les lectures (oracle paresse/cache) et simule un
/// asset absent (throw) sans toucher au disque.
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
  {"iso":"NE","name":"Niger","dialCode":"+227","flag":"🇳🇪"},
  {"iso":"FR","name":"France","dialCode":"+33","flag":"🇫🇷"}
]''';

void main() {
  group('AC4 — chargement paresseux + cache', () {
    test('load() ne lit l\'asset qu\'une seule fois (cache)', () async {
      final bundle = _FakeBundle(_json);
      final cat = ZCountryCatalog(bundle: bundle);
      expect(cat.isLoaded, isFalse);
      expect(bundle.stringLoads, 0); // PARESSE : rien lu avant load()

      final first = await cat.load();
      expect(first, hasLength(2));
      expect(cat.isLoaded, isTrue);
      expect(bundle.stringLoads, 1);

      final second = await cat.load();
      expect(second, hasLength(2));
      expect(bundle.stringLoads, 1); // CACHE : pas de 2e lecture
      expect(cat.assetReads, 1);
    });

    test('MEDIUM-1 : 2 load() CONCURRENTS → asset lu/parsé UNE seule fois',
        () async {
      // Cas normal DODLP : deux pickers (address + phone/country) partageant le
      // MÊME catalogue asset-backed, montés dans la même frame, appellent load()
      // sans attendre. La charge en vol doit être mémoïsée (invariant « chargé
      // une seule fois »).
      final bundle = _FakeBundle(_json);
      final cat = ZCountryCatalog(bundle: bundle);

      final f1 = cat.load();
      final f2 = cat.load();
      // Le MÊME Future en vol est partagé (aucun second appel bundle).
      expect(identical(f1, f2), isTrue);

      final r1 = await f1;
      final r2 = await f2;
      expect(r1, hasLength(2));
      expect(identical(r1, r2), isTrue);
      // Oracle : une seule lecture ET un seul parse de l'asset des pays.
      expect(bundle.stringLoads, 1);
      expect(cat.assetReads, 1);

      // Après résolution, un 3e load() sert le cache sans relire l'asset.
      await cat.load();
      expect(bundle.stringLoads, 1);
      expect(cat.assetReads, 1);
    });
  });

  group('LOW-1 — catalogue par défaut PARTAGÉ (une lecture pour les 3 kinds)', () {
    test('sharedDefaultCountryCatalog() retourne une instance stable partagée',
        () {
      final a = sharedDefaultCountryCatalog();
      final b = sharedDefaultCountryCatalog();
      expect(identical(a, b), isTrue);
    });

    test('byIso + search sur catalogue chargé', () async {
      final cat = ZCountryCatalog(bundle: _FakeBundle(_json));
      await cat.load();
      expect(cat.byIso('ne')?.name, 'Niger');
      expect(cat.byIso('ZZ'), isNull);
      expect(cat.search('fra').single.isoCode, 'FR');
      expect(cat.search('+227').single.isoCode, 'NE');
      expect(cat.search(''), hasLength(2));
    });
  });

  group('AC4 — injectable (fromList, sans disque)', () {
    test('fromList pré-chargé : aucune lecture d\'asset', () async {
      final cat = ZCountryCatalog.fromList(const <ZCountryInfo>[
        ZCountryInfo(isoCode: 'NE', name: 'Niger', dialCode: '+227'),
      ]);
      final list = await cat.load();
      expect(list, hasLength(1));
      expect(cat.assetReads, 0);
      expect(cat.byIso('NE')?.dialCode, '+227');
    });
  });

  group('AC5 — défensif : asset absent / JSON malformé → catalogue vide', () {
    test('asset introuvable → vide, jamais de throw', () async {
      final cat = ZCountryCatalog(bundle: _FakeBundle.missing());
      late List<ZCountryInfo> list;
      await expectLater(() async => list = await cat.load(), returnsNormally);
      expect(list, isEmpty);
      expect(cat.isLoaded, isTrue);
    });

    test('JSON malformé → vide, jamais de throw', () async {
      final cat = ZCountryCatalog(bundle: _FakeBundle('{ pas du json ['));
      final list = await cat.load();
      expect(list, isEmpty);
    });

    test('JSON = objet (non-liste) → vide', () async {
      final cat = ZCountryCatalog(bundle: _FakeBundle('{"iso":"NE"}'));
      expect(await cat.load(), isEmpty);
    });

    test('entrées non conformes ignorées, valides conservées', () async {
      final cat = ZCountryCatalog(
        bundle: _FakeBundle('[{"name":"sans iso"},{"iso":"NE"},42]'),
      );
      final list = await cat.load();
      expect(list, hasLength(1));
      expect(list.single.isoCode, 'NE');
    });

    test('search/byIso avant load → vide/null (jamais de throw)', () {
      final cat = ZCountryCatalog(bundle: _FakeBundle(_json));
      expect(cat.search('x'), isEmpty);
      expect(cat.byIso('NE'), isNull);
    });
  });

  group('asset réel bundlé — parité DODLP', () {
    testWidgets('countries.json bundlé charge un catalogue non trivial',
        (tester) async {
      // Le vrai rootBundle du binding de test expose l'asset du PROPRE package
      // sous la clé `lib/...` ; les consommateurs utilisent le préfixe
      // `packages/zcrud_intl/...` ([kDefaultCountriesAsset], défaut de prod).
      final cat = ZCountryCatalog(assetPath: 'lib/assets/countries.json');
      final list = await cat.load();
      expect(list.length, greaterThan(100));
      expect(cat.byIso('NE')?.name, 'Niger');
      expect(cat.byIso('NE')?.dialCode, '+227');
    });
  });
}
