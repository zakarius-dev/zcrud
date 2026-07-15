/// Registre de **modèles** `kind → (fromMap, toMap)` (AD-3, AD-4 pt.3).
///
/// origine: lex_core (module « Étude ») — patron « registre ouvert »
/// (canonique §4 pt.3). Consommé par **E2-5** : chaque `@ZcrudModel` génère un
/// appel `register<T>(kind, fromMap: …, toMap: …)` prenant une **instance** de
/// [ZcrudRegistry] (injection au bootstrap, cf. E7-2) — le codegen n'a pas à
/// lister les modèles à la main, et « type non enregistré → throw explicite ».
library;

import '../edition/z_field_spec.dart';
import 'z_codec_registry.dart';
import 'z_decode_context.dart';
import 'z_registry_error.dart';

/// Reconstruit un modèle depuis sa map persistée.
typedef ZFromMap = Object Function(Map<String, dynamic> map);

/// Sérialise un modèle vers sa map persistée.
typedef ZToMap = Map<String, dynamic> Function(Object value);

/// Reconstruit un modèle en fournissant le [ZDecodeContext] injecté (DW-ES14-2)
/// aux `fromMap` d'entité extensible (`extensionParser`/`sourceRegistry`, AD-4).
typedef ZFromMapWithContext = Object Function(
  Map<String, dynamic> map,
  ZDecodeContext? context,
);

/// Sérialise un modèle en fournissant le [ZDecodeContext] injecté (provenance
/// `source`) au `toMap` d'entité (DW-ES14-2).
typedef ZToMapWithContext = Map<String, dynamic> Function(
  Object value,
  ZDecodeContext? context,
);

/// Couple de (dé)sérialisation d'un **modèle** enregistré, discriminé par
/// [kind]. Immuable (`const`), `==`/`hashCode` non requis (identité de codec).
class ZModelCodec {
  /// Construit le codec pour [kind] à partir de [fromMap]/[toMap].
  ///
  /// [fromMapWithContext]/[toMapWithContext] (DW-ES14-2, **additifs**, `null` par
  /// defaut) portent les variantes **conscientes du contexte** : emises par le
  /// generateur pour toute entite dont la factory de domaine accepte un
  /// `extensionParser` et/ou un `sourceRegistry` (AD-4). Quand ils sont `null`, le
  /// registre retombe sur [fromMap]/[toMap] : comportement **identique** a avant.
  const ZModelCodec({
    required this.kind,
    required this.fromMap,
    required this.toMap,
    this.fromMapWithContext,
    this.toMapWithContext,
  });

  /// Discriminant du modèle (ex. `"flashcard"`).
  final String kind;

  /// Reconstruit une instance depuis une map persistée (**sans** contexte).
  final ZFromMap fromMap;

  /// Sérialise une instance vers une map persistée (**sans** contexte).
  final ZToMap toMap;

  /// Variante **consciente du contexte** de [fromMap] (DW-ES14-2), ou `null` si
  /// l'entite ne consomme aucun collaborateur injectable.
  final ZFromMapWithContext? fromMapWithContext;

  /// Variante **consciente du contexte** de [toMap] (DW-ES14-2), ou `null`.
  final ZToMapWithContext? toMapWithContext;
}

/// Registre **instanciable** de modèles (PAS un singleton statique mutable —
/// Dev Notes #2 : instances injectées via `ZcrudScope`/binding, pour
/// l'isolation inter-app OQ-6 et la testabilité).
///
/// **Slot `ZFieldSpec` différé (dépendance E2-4/E2-5)** : `ZFieldSpec` n'existe
/// pas avant E2-4/E2-5. Cette version porte `fromMap`/`toMap` **seulement** ;
/// l'association `kind → List<ZFieldSpec>` sera ajoutée **additivement** en
/// E2-4/E2-5 (paramètre optionnel `fieldSpecs` sur [register], ou seconde map
/// interne), **sans casser** la signature actuelle (AD-10 additif). On
/// n'introduit **pas** de slot `Object?` non typé « en attendant » (fuite d'API).
class ZcrudRegistry {
  /// Construit un registre de modèles vide.
  ///
  /// [decodeContext] (DW-ES14-2, **additif** — AD-10) est cable **une fois** au
  /// bootstrap : le registre le thread aux `fromMap`/`toMap` conscients du
  /// contexte des entites extensibles, sans changer la signature de [decode]/
  /// [encode]. `ZcrudRegistry()` **sans** contexte se comporte **exactement**
  /// comme avant (retro-compat prouvee par test).
  // Le slot est PRIVE (`_decodeContext`) mais expose en parametre NOMME public
  // (`decodeContext`) : Dart interdit un formal d'initialisation nomme prive
  // (`this._decodeContext`), l'assignation en liste est donc la SEULE forme.
  ZcrudRegistry({ZDecodeContext? decodeContext})
      // ignore: prefer_initializing_formals
      : _decodeContext = decodeContext;

  /// Contexte de (de)codage injecte (DW-ES14-2), ou `null` (voie historique).
  final ZDecodeContext? _decodeContext;

  final ZCodecRegistry<ZModelCodec> _codecs =
      ZCodecRegistry<ZModelCodec>('ZcrudRegistry');

  /// Seconde map interne `kind → List<ZFieldSpec>` (slot réservé additivement
  /// par E2-3, câblé en E2-5). Alimentée par le paramètre optionnel
  /// [register]`.fieldSpecs`. Indépendante des codecs : un modèle peut être
  /// enregistré sans schéma (défaut `const []`).
  final Map<String, List<ZFieldSpec>> _fieldSpecs = <String, List<ZFieldSpec>>{};

  /// Enregistre le couple (dé)sérialisation typé de [kind] et, additivement,
  /// son schéma déclaratif [fieldSpecs] (projeté depuis `@ZcrudField` par E2-5).
  ///
  /// Les callbacks sont **typés `T`** côté appelant (émis par le codegen) et
  /// adaptés vers `Object` en interne (cast sûr côté [toMap], le décodage
  /// produisant déjà un `T <: Object`). Collision → `throw`
  /// [ZDuplicateRegistrationError].
  ///
  /// [fieldSpecs] (défaut `const []`, **rétro-compatible** — AD-10 additif) est
  /// la projection `List<ZFieldSpec>` émise par E2-5 ; consommée par E3
  /// (formulaire) et E4 (liste). Le codec est enregistré **avant** le schéma :
  /// une collision de [kind] laisse `_fieldSpecs` inchangé.
  ///
  /// [fromMapWithContext]/[toMapWithContext] (DW-ES14-2, **additifs**, `null` par
  /// defaut — AD-10) portent les variantes conscientes du contexte. Emis par le
  /// generateur pour toute entite dont la factory de domaine accepte un
  /// `extensionParser` et/ou un `sourceRegistry` ; ignores (retombee sur
  /// [fromMap]/[toMap]) pour les autres.
  void register<T extends Object>(
    String kind, {
    required T Function(Map<String, dynamic> map) fromMap,
    required Map<String, dynamic> Function(T value) toMap,
    List<ZFieldSpec> fieldSpecs = const <ZFieldSpec>[],
    ZFromMapWithContext? fromMapWithContext,
    Map<String, dynamic> Function(T value, ZDecodeContext? context)?
        toMapWithContext,
  }) {
    _codecs.register(
      kind,
      ZModelCodec(
        kind: kind,
        fromMap: fromMap,
        toMap: (Object value) => toMap(value as T),
        fromMapWithContext: fromMapWithContext,
        toMapWithContext: toMapWithContext == null
            ? null
            : (Object value, ZDecodeContext? ctx) =>
                toMapWithContext(value as T, ctx),
      ),
    );
    _fieldSpecs[kind] = fieldSpecs;
  }

  /// Schéma déclaratif [ZFieldSpec] enregistré pour [kind] (peut être vide si le
  /// modèle a été enregistré sans schéma), ou **`throw`**
  /// [ZUnregisteredTypeError] si [kind] n'est pas enregistré (frontière stricte,
  /// AD-3 — parallèle à [codecFor]).
  List<ZFieldSpec> fieldSpecsFor(String kind) {
    if (!_codecs.isRegistered(kind)) {
      throw ZUnregisteredTypeError(kind: kind, registryName: 'ZcrudRegistry');
    }
    return _fieldSpecs[kind] ?? const <ZFieldSpec>[];
  }

  /// Schéma déclaratif de [kind], ou `null` si [kind] n'est pas enregistré
  /// (variante **défensive** pour un appelant tolérant, AD-10 — parallèle à
  /// [tryCodecFor]).
  List<ZFieldSpec>? tryFieldSpecsFor(String kind) =>
      _codecs.isRegistered(kind) ? (_fieldSpecs[kind] ?? const <ZFieldSpec>[]) : null;

  /// `true` si un modèle est enregistré pour [kind].
  bool isRegistered(String kind) => _codecs.isRegistered(kind);

  /// Les `kind` de modèles actuellement enregistrés.
  Iterable<String> get kinds => _codecs.kinds;

  /// Retourne le [ZModelCodec] de [kind], ou **`throw`**
  /// [ZUnregisteredTypeError] si absent (frontière modèle stricte, AD-3).
  ZModelCodec codecFor(String kind) => _codecs.entryFor(kind);

  /// Retourne le [ZModelCodec] de [kind], ou `null` si absent (variante
  /// **défensive** pour un appelant tolérant, AD-10).
  ZModelCodec? tryCodecFor(String kind) => _codecs.tryEntryFor(kind);

  /// Décode [map] en un modèle via le codec de [kind] (**throw** si [kind]
  /// non enregistré, AD-3).
  ///
  /// DW-ES14-2 : si le codec porte une variante consciente du contexte
  /// (`fromMapWithContext`), le [ZDecodeContext] injecte au bootstrap y est
  /// **threade** (resolution typee de `extension`/`source`, AD-4). Sinon —
  /// entite non extensible, ou contexte non cable — comportement **identique** a
  /// la voie historique (`fromMap` nu). La signature reste **INCHANGEE**.
  Object decode(String kind, Map<String, dynamic> map) {
    final codec = codecFor(kind);
    final withContext = codec.fromMapWithContext;
    return withContext != null
        ? withContext(map, _decodeContext)
        : codec.fromMap(map);
  }

  /// Encode [value] en map via le codec de [kind] (**throw** si [kind] non
  /// enregistré, AD-3).
  ///
  /// DW-ES14-2 : symetrique de [decode] — le contexte (provenance `source`) est
  /// threade si le codec porte une variante `toMapWithContext`.
  Map<String, dynamic> encode(String kind, Object value) {
    final codec = codecFor(kind);
    final withContext = codec.toMapWithContext;
    return withContext != null
        ? withContext(value, _decodeContext)
        : codec.toMap(value);
  }
}
