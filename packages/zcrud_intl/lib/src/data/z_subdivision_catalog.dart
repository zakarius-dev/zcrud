/// `ZSubdivisionCatalog` — **catalogue états/provinces indexé par pays**
/// (E11b-2, FR-21, AD-1/AD-10/AD-12). Même discipline que `ZCountryCatalog`
/// (paresse + cache + dé-dup `_loading` MEDIUM-1 + injection + défensif +
/// partagé LOW-1), mais **indexé par pays** (`{ "NE": [...], "US": [...] }`).
///
/// origine: le sélecteur d'état/province (`ZStateField`) et le sous-champ
/// `region` de `ZAddressField` ont besoin des subdivisions ISO 3166-2 **du pays
/// courant**. Ces listes vivent dans un **asset JSON bundlé**
/// (`lib/assets/subdivisions.json`), chargé **à la première demande** ([load]),
/// puis **mis en cache** (lecture seule, immuable).
///
/// **Périmètre pragmatique** : sous-ensemble **curaté et documenté** (pays
/// prioritaires DODLP/lex_douane + échantillon multi-continent). Le catalogue est
/// **injectable/extensible** ([ZSubdivisionCatalog.fromMap]) → couverture ISO
/// 3166-2 exhaustive = v2. Aucun défaut national codé en dur non surchargeable.
///
/// **Défensif (AD-10)** : [load] ne **throw jamais** ; asset absent / JSON
/// malformé / pays inconnu → **liste vide**. **Isolation (AD-1)** : aucune lib
/// tierce. **Zéro secret / réseau** (AD-12).
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/z_subdivision.dart';

/// Chemin **package** de l'asset bundlé (résolu au runtime par `rootBundle`).
const String kDefaultSubdivisionsAsset =
    'packages/zcrud_intl/assets/subdivisions.json';

/// Instance PARTAGÉE lazy du catalogue par défaut (LOW-1).
ZSubdivisionCatalog? _sharedDefaultSubdivisionCatalog;

/// Catalogue subdivisions par défaut **partagé** (paresseux) : plusieurs
/// `ZStateField`/adresses sans `catalog` injecté partagent CETTE instance → une
/// seule lecture d'asset.
ZSubdivisionCatalog sharedDefaultSubdivisionCatalog() =>
    _sharedDefaultSubdivisionCatalog ??= ZSubdivisionCatalog();

/// Catalogue états/provinces paresseux + caché, indexé par pays, injectable.
class ZSubdivisionCatalog {
  /// Catalogue **chargé depuis un asset** (paresseux). [assetPath] par défaut
  /// pointe l'asset bundlé ; [bundle] permet d'injecter un `AssetBundle` de test.
  ZSubdivisionCatalog({
    String assetPath = kDefaultSubdivisionsAsset,
    AssetBundle? bundle,
  })  : _assetPath = assetPath, // ignore: prefer_initializing_formals
        _bundle = bundle, // ignore: prefer_initializing_formals
        _preloaded = null;

  /// Catalogue **pré-chargé** depuis une map pays→subdivisions en mémoire
  /// (injection de test / surcharge sans disque). Aucune lecture d'asset.
  ZSubdivisionCatalog.fromMap(Map<String, List<ZSubdivision>> byCountry)
      : _assetPath = kDefaultSubdivisionsAsset,
        _bundle = null,
        _preloaded = <String, List<ZSubdivision>>{
          for (final e in byCountry.entries)
            e.key.toUpperCase():
                List<ZSubdivision>.unmodifiable(e.value),
        };

  final String _assetPath;
  final AssetBundle? _bundle;
  final Map<String, List<ZSubdivision>>? _preloaded;

  Map<String, List<ZSubdivision>>? _cache;

  /// Chargement **en vol** mémoïsé (MEDIUM-1). Effacé à la résolution.
  Future<Map<String, List<ZSubdivision>>>? _loading;

  int _assetReads = 0;

  /// Lectures d'asset effectuées (test-only : prouve paresse + cache).
  int get assetReads => _assetReads;

  /// `true` si [load] a déjà résolu (cache présent).
  bool get isLoaded => _cache != null;

  /// Charge le catalogue **une seule fois** (paresseux + cache) et ne throw
  /// jamais (AD-10). Asset absent / JSON malformé → catalogue vide.
  Future<Map<String, List<ZSubdivision>>> load() {
    final cached = _cache;
    if (cached != null) {
      return Future<Map<String, List<ZSubdivision>>>.value(cached);
    }
    final preloaded = _preloaded;
    if (preloaded != null) {
      _commit(preloaded);
      return Future<Map<String, List<ZSubdivision>>>.value(_cache!);
    }
    return _loading ??= _loadFromAsset();
  }

  Future<Map<String, List<ZSubdivision>>> _loadFromAsset() async {
    Map<String, List<ZSubdivision>> parsed;
    try {
      _assetReads++;
      final raw = await (_bundle ?? rootBundle).loadString(_assetPath);
      parsed = _parse(raw);
    } catch (_) {
      parsed = const <String, List<ZSubdivision>>{};
    }
    _commit(parsed);
    _loading = null;
    return _cache!;
  }

  void _commit(Map<String, List<ZSubdivision>> map) {
    _cache = <String, List<ZSubdivision>>{
      for (final e in map.entries)
        e.key.toUpperCase(): List<ZSubdivision>.unmodifiable(e.value),
    };
  }

  /// Parse **défensif** (AD-10) : non-objet → vide ; buckets non-listes ignorés ;
  /// entrées non conformes ignorées ([ZSubdivision.fromMapSafe] → `null`). Le code
  /// pays du bucket est propagé comme `countryIso` de contexte.
  static Map<String, List<ZSubdivision>> _parse(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const <String, List<ZSubdivision>>{};
    }
    if (decoded is! Map) return const <String, List<ZSubdivision>>{};
    final out = <String, List<ZSubdivision>>{};
    for (final entry in decoded.entries) {
      final iso = entry.key;
      final value = entry.value;
      if (iso is! String || iso.isEmpty || value is! List) continue;
      final list = <ZSubdivision>[
        for (final e in value)
          if (ZSubdivision.fromMapSafe(e, countryIso: iso)
              case final ZSubdivision s)
            s,
      ];
      if (list.isNotEmpty) out[iso.toUpperCase()] = list;
    }
    return out;
  }

  /// Subdivisions du pays [iso] (insensible à la casse) ; **liste vide** si pays
  /// inconnu ou catalogue non chargé (AD-10, jamais throw).
  List<ZSubdivision> forCountry(String iso) =>
      _cache?[iso.toUpperCase()] ?? const <ZSubdivision>[];

  /// `true` si le pays [iso] a au moins une subdivision au catalogue.
  bool hasCountry(String iso) => forCountry(iso).isNotEmpty;

  /// Recherche une subdivision par code ISO 3166-2 [code] dans le pays [iso].
  ZSubdivision? byCode(String iso, String code) {
    final up = code.toUpperCase();
    for (final s in forCountry(iso)) {
      if (s.code.toUpperCase() == up) return s;
    }
    return null;
  }
}
