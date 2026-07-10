/// `ZCurrencyCatalog` — **catalogue devise chargé paresseusement** (E11b-2,
/// FR-21, AD-1/AD-10/AD-12). Calqué **à l'identique** sur `ZCountryCatalog`
/// (paresse + cache + dé-dup `_loading` MEDIUM-1 + `fromList`/`bundle` + défensif
/// + partagé LOW-1).
///
/// origine: le sélecteur de code devise (`ZCurrencyField`) a besoin de la liste
/// ISO 4217 (code, nom, symbole, décimales). Cette liste vit dans un **asset JSON
/// bundlé** (`lib/assets/currencies.json`), chargé **à la première demande**
/// ([load]) via `rootBundle`, puis **mis en cache** (lecture seule, immuable →
/// cache partageable légitime, PAS une ressource disposable).
///
/// **Défensif (AD-10)** : [load] ne **throw jamais**. Asset absent, JSON malformé,
/// entrée non conforme → catalogue **vide**. **Isolation (AD-1)** : aucune lib
/// devise ici. **Zéro secret / zéro réseau** (AD-12).
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/z_currency_info.dart';

/// Chemin **package** de l'asset bundlé (résolu au runtime par `rootBundle`).
const String kDefaultCurrenciesAsset =
    'packages/zcrud_intl/assets/currencies.json';

/// Instance PARTAGÉE lazy du catalogue par défaut (LOW-1).
ZCurrencyCatalog? _sharedDefaultCurrencyCatalog;

/// Catalogue devise par défaut **partagé** (paresseux) : plusieurs
/// `ZCurrencyField` sans `catalog` injecté partagent CETTE instance → **une
/// seule** lecture d'asset.
ZCurrencyCatalog sharedDefaultCurrencyCatalog() =>
    _sharedDefaultCurrencyCatalog ??= ZCurrencyCatalog();

/// Catalogue devise paresseux + caché, injectable (AD-1/AD-10/FR-21).
class ZCurrencyCatalog {
  /// Catalogue **chargé depuis un asset** (paresseux). [assetPath] par défaut
  /// pointe l'asset bundlé ; [bundle] permet d'injecter un `AssetBundle` de test.
  ZCurrencyCatalog({
    String assetPath = kDefaultCurrenciesAsset,
    AssetBundle? bundle,
  })  : _assetPath = assetPath, // ignore: prefer_initializing_formals
        _bundle = bundle, // ignore: prefer_initializing_formals
        _preloaded = null;

  /// Catalogue **pré-chargé** depuis une liste en mémoire (injection de test /
  /// surcharge sans disque). Aucune lecture d'asset ne sera tentée.
  ZCurrencyCatalog.fromList(List<ZCurrencyInfo> currencies)
      : _assetPath = kDefaultCurrenciesAsset,
        _bundle = null,
        _preloaded = List<ZCurrencyInfo>.unmodifiable(currencies);

  final String _assetPath;
  final AssetBundle? _bundle;
  final List<ZCurrencyInfo>? _preloaded;

  List<ZCurrencyInfo>? _cache;
  Map<String, ZCurrencyInfo> _byCode = const <String, ZCurrencyInfo>{};

  /// Chargement **en vol** mémoïsé (MEDIUM-1) : l'asset n'est lu/parsé qu'une
  /// seule fois sous charges concurrentes. Effacé à la résolution.
  Future<List<ZCurrencyInfo>>? _loading;

  int _assetReads = 0;

  /// Lectures d'asset effectuées (test-only : prouve paresse + cache).
  int get assetReads => _assetReads;

  /// `true` si [load] a déjà résolu (cache présent).
  bool get isLoaded => _cache != null;

  /// Vue lecture seule du cache (`null` si pas encore chargé).
  List<ZCurrencyInfo>? get cached => _cache;

  /// Charge le catalogue **une seule fois** (paresseux + cache) et ne throw
  /// jamais (AD-10). Asset absent / JSON malformé → catalogue vide.
  Future<List<ZCurrencyInfo>> load() {
    final cached = _cache;
    if (cached != null) return Future<List<ZCurrencyInfo>>.value(cached);
    final preloaded = _preloaded;
    if (preloaded != null) {
      _commit(preloaded);
      return Future<List<ZCurrencyInfo>>.value(_cache!);
    }
    return _loading ??= _loadFromAsset();
  }

  Future<List<ZCurrencyInfo>> _loadFromAsset() async {
    List<ZCurrencyInfo> parsed;
    try {
      _assetReads++;
      final raw = await (_bundle ?? rootBundle).loadString(_assetPath);
      parsed = _parse(raw);
    } catch (_) {
      parsed = const <ZCurrencyInfo>[];
    }
    _commit(parsed);
    _loading = null;
    return _cache!;
  }

  void _commit(List<ZCurrencyInfo> list) {
    _cache = List<ZCurrencyInfo>.unmodifiable(list);
    _byCode = <String, ZCurrencyInfo>{
      for (final c in _cache!) c.code.toUpperCase(): c,
    };
  }

  /// Parse **défensif** (AD-10) : non-liste → vide ; entrées non conformes
  /// ignorées ([ZCurrencyInfo.fromMapSafe] → `null`).
  static List<ZCurrencyInfo> _parse(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const <ZCurrencyInfo>[];
    }
    if (decoded is! List) return const <ZCurrencyInfo>[];
    return <ZCurrencyInfo>[
      for (final e in decoded)
        if (ZCurrencyInfo.fromMapSafe(e) case final ZCurrencyInfo c) c,
    ];
  }

  /// Recherche l'entrée du code devise [code] (insensible à la casse) ; `null`
  /// si absent ou catalogue non chargé (AD-10).
  ZCurrencyInfo? byCode(String code) => _byCode[code.toUpperCase()];

  /// Filtre le cache par [query] (code, nom ou symbole ; insensible à la casse).
  /// Catalogue non chargé → liste vide. Requête vide → tout le cache.
  List<ZCurrencyInfo> search(String query) {
    final list = _cache;
    if (list == null) return const <ZCurrencyInfo>[];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return <ZCurrencyInfo>[
      for (final c in list)
        if (c.code.toLowerCase().contains(q) ||
            (c.name?.toLowerCase().contains(q) ?? false) ||
            (c.symbol?.toLowerCase().contains(q) ?? false))
          c,
    ];
  }
}
