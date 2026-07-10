/// `ZCountryCatalog` — **catalogue pays chargé paresseusement** (E11a-2, FR-21,
/// AD-1/AD-10/AD-12).
///
/// origine: le picker pays et la liaison indicatif du champ téléphone ont besoin
/// de la liste des pays (code ISO, nom, indicatif, drapeau). Cette liste vit dans
/// un **asset JSON bundlé** dans `zcrud_intl` (`lib/assets/countries.json`),
/// chargé **à la première demande** ([load]) via `rootBundle`, puis **mis en
/// cache** (lecture seule, immuable → cache partageable légitime : ce n'est PAS
/// une ressource disposable — learning MAJEUR-1 E11a-1).
///
/// **Injectable/surchargeable** : un [ZCountryCatalog.fromList] pré-chargé
/// (tests, défaut national surchargeable) évite tout accès disque et tout défaut
/// codé en dur non surchargeable. Un [AssetBundle] alternatif peut aussi être
/// injecté (preuve de paresse/cache en test sans disque réel).
///
/// **Défensif (AD-10)** : [load] ne **throw jamais**. Asset absent, JSON
/// malformé, entrée non conforme → catalogue **vide** (jamais d'exception).
///
/// **Isolation (AD-1)** : aucune lib intl/téléphone ici ; uniquement des
/// [ZCountryInfo] neutres. **Zéro secret / zéro réseau** (AD-12).
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/z_country_info.dart';

/// Chemin **package** de l'asset bundlé (résolu au runtime par `rootBundle`).
const String kDefaultCountriesAsset = 'packages/zcrud_intl/assets/countries.json';

/// Instance PARTAGÉE lazy du catalogue par défaut (LOW-1 E11a-2).
ZCountryCatalog? _sharedDefaultCatalog;

/// Catalogue par défaut **partagé** (paresseux) : si plusieurs champs intl
/// (`phoneNumber`/`country`/`address`) sont enregistrés sans injecter de
/// `catalog`, ils partagent CETTE instance → **une seule** lecture d'asset (au
/// lieu d'une par kind). Surchargeable en injectant explicitement un catalogue
/// dédié dans les factories `.builder(...)`.
ZCountryCatalog sharedDefaultCountryCatalog() =>
    _sharedDefaultCatalog ??= ZCountryCatalog();

/// Catalogue pays paresseux + caché, injectable (AD-1/AD-10/FR-21).
class ZCountryCatalog {
  /// Catalogue **chargé depuis un asset** (paresseux). [assetPath] par défaut
  /// pointe l'asset bundlé ; [bundle] permet d'injecter un `AssetBundle` de test
  /// (défaut `rootBundle`).
  ZCountryCatalog({
    String assetPath = kDefaultCountriesAsset,
    AssetBundle? bundle,
  })  : _assetPath = assetPath, // ignore: prefer_initializing_formals
        _bundle = bundle, // ignore: prefer_initializing_formals
        _preloaded = null;

  /// Catalogue **pré-chargé** depuis une liste en mémoire (injection de test /
  /// surcharge sans disque). Aucune lecture d'asset ne sera tentée.
  ZCountryCatalog.fromList(List<ZCountryInfo> countries)
      : _assetPath = kDefaultCountriesAsset,
        _bundle = null,
        _preloaded = List<ZCountryInfo>.unmodifiable(countries);

  final String _assetPath;
  final AssetBundle? _bundle;
  final List<ZCountryInfo>? _preloaded;

  /// Cache immuable (null tant que [load] n'a pas résolu).
  List<ZCountryInfo>? _cache;

  /// Index ISO→pays dérivé du cache (construit à la résolution).
  Map<String, ZCountryInfo> _byIso = const <String, ZCountryInfo>{};

  /// Chargement **en vol** mémoïsé (MEDIUM-1) : tant que la première lecture
  /// d'asset n'est pas résolue, tout appel concurrent de [load] reçoit CE même
  /// `Future` → l'asset n'est lu/parsé qu'**une seule fois**. Effacé à la
  /// résolution.
  Future<List<ZCountryInfo>>? _loading;

  /// Nombre de lectures d'asset réellement effectuées (oracle de test « cache »
  /// et « paresse » ; incrémenté seulement quand `bundle.loadString` est appelé).
  int _assetReads = 0;

  /// Lectures d'asset effectuées (test-only : prouve paresse + cache).
  int get assetReads => _assetReads;

  /// `true` si [load] a déjà résolu (cache présent).
  bool get isLoaded => _cache != null;

  /// Vue lecture seule du cache (`null` si pas encore chargé).
  List<ZCountryInfo>? get cached => _cache;

  /// Charge le catalogue **une seule fois** (paresseux + cache) et ne throw
  /// jamais (AD-10). Asset absent / JSON malformé → catalogue vide.
  Future<List<ZCountryInfo>> load() {
    final cached = _cache;
    if (cached != null) return Future<List<ZCountryInfo>>.value(cached);
    // Catalogue pré-chargé : commit synchrone, aucun `Future` en vol à mémoïser.
    final preloaded = _preloaded;
    if (preloaded != null) {
      _commit(preloaded);
      return Future<List<ZCountryInfo>>.value(_cache!);
    }
    // Dé-duplication de la charge en vol (MEDIUM-1) : deux pickers montés dans la
    // même frame et partageant CE catalogue reçoivent le MÊME `Future` → asset lu
    // et parsé une seule fois. Effacé à la résolution (via [_loadFromAsset]).
    return _loading ??= _loadFromAsset();
  }

  /// Lecture+parse de l'asset (une seule fois par catalogue, mémoïsée par
  /// [load]). Ne throw jamais (AD-10) : asset absent / JSON malformé → vide.
  Future<List<ZCountryInfo>> _loadFromAsset() async {
    List<ZCountryInfo> parsed;
    try {
      _assetReads++;
      final raw = await (_bundle ?? rootBundle).loadString(_assetPath);
      parsed = _parse(raw);
    } catch (_) {
      // Asset absent / erreur d'IO → catalogue vide, jamais de throw (AD-10).
      parsed = const <ZCountryInfo>[];
    }
    _commit(parsed);
    _loading = null;
    return _cache!;
  }

  void _commit(List<ZCountryInfo> list) {
    _cache = List<ZCountryInfo>.unmodifiable(list);
    _byIso = <String, ZCountryInfo>{
      for (final c in _cache!) c.isoCode.toUpperCase(): c,
    };
  }

  /// Parse **défensif** du JSON (AD-10) : non-liste → vide ; entrées non
  /// conformes ignorées ([ZCountryInfo.fromMapSafe] → `null`).
  static List<ZCountryInfo> _parse(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const <ZCountryInfo>[];
    }
    if (decoded is! List) return const <ZCountryInfo>[];
    return <ZCountryInfo>[
      for (final e in decoded)
        if (ZCountryInfo.fromMapSafe(e) case final ZCountryInfo c) c,
    ];
  }

  /// Recherche l'entrée du code ISO [isoCode] dans le cache (insensible à la
  /// casse) ; `null` si absent ou catalogue non chargé (AD-10).
  ZCountryInfo? byIso(String isoCode) => _byIso[isoCode.toUpperCase()];

  /// Filtre le cache par [query] (nom, code ISO ou indicatif ; insensible à la
  /// casse). Catalogue non chargé → liste vide. Requête vide → tout le cache.
  List<ZCountryInfo> search(String query) {
    final list = _cache;
    if (list == null) return const <ZCountryInfo>[];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return <ZCountryInfo>[
      for (final c in list)
        if ((c.name?.toLowerCase().contains(q) ?? false) ||
            c.isoCode.toLowerCase().contains(q) ||
            (c.dialCode?.contains(q) ?? false))
          c,
    ];
  }
}
