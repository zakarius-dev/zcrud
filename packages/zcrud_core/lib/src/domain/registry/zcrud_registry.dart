/// Registre de **modèles** `kind → (fromMap, toMap)` (AD-3, AD-4 pt.3).
///
/// Chaque `@ZcrudModel` fait générer un appel
/// `register<T>(kind, fromMap: …, toMap: …)` prenant une **instance** de
/// [ZcrudRegistry] (injection au
/// bootstrap de l'application) — le codegen n'a pas à lister les modèles à la
/// main, et « type non enregistré → throw explicite ».
library;

import '../edition/z_field_spec.dart';
import 'z_codec_registry.dart';
import 'z_decode_context.dart';
import 'z_registry_error.dart';

/// Reconstruit un modèle depuis sa map persistée.
typedef ZFromMap = Object Function(Map<String, dynamic> map);

/// Sérialise un modèle vers sa map persistée.
typedef ZToMap = Map<String, dynamic> Function(Object value);

/// Reconstruit un modèle en fournissant le [ZDecodeContext] injecté
/// aux `fromMap` d'entité extensible (`extensionParser`/`sourceRegistry`, AD-4).
typedef ZFromMapWithContext = Object Function(
  Map<String, dynamic> map,
  ZDecodeContext? context,
);

/// Sérialise un modèle en fournissant le [ZDecodeContext] injecté (provenance
/// `source`) au `toMap` d'entité.
typedef ZToMapWithContext = Map<String, dynamic> Function(
  Object value,
  ZDecodeContext? context,
);

/// Couple de (dé)sérialisation d'un **modèle** enregistré, discriminé par
/// [kind]. Immuable (`const`), `==`/`hashCode` non requis (identité de codec).
class ZModelCodec {
  /// Construit le codec pour [kind] à partir de [fromMap]/[toMap].
  ///
  /// [fromMapWithContext]/[toMapWithContext] (**additifs**, `null` par
  /// défaut) portent les variantes **conscientes du contexte** : émises par le
  /// générateur pour toute entité dont la factory de domaine accepte un
  /// `extensionParser` et/ou un `sourceRegistry` (AD-4). Quand ils sont `null`, le
  /// registre retombe sur [fromMap]/[toMap] : comportement **identique** sans
  /// contexte.
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

  /// Variante **consciente du contexte** de [fromMap], ou `null` si
  /// l'entité ne consomme aucun collaborateur injectable.
  final ZFromMapWithContext? fromMapWithContext;

  /// Variante **consciente du contexte** de [toMap], ou `null`.
  final ZToMapWithContext? toMapWithContext;
}

/// Registre **instanciable** de modèles (PAS un singleton statique mutable :
/// instances injectées via `ZcrudScope`/binding, pour l'isolation inter-app
/// et la testabilité).
///
/// Porte `fromMap`/`toMap`, et — additivement — l'association
/// `kind → List<ZFieldSpec>` (paramètre optionnel `fieldSpecs` sur
/// [register]) sans
/// casser la signature de base (AD-10 additif). Aucun slot `Object?` non typé
/// « en attendant » (fuite d'API évitée par construction).
class ZcrudRegistry {
  /// Construit un registre de modèles vide.
  ///
  /// [decodeContext] (**additif** — AD-10) est câblé **une fois** au
  /// bootstrap : le registre le thread aux `fromMap`/`toMap` conscients du
  /// contexte des entités extensibles, sans changer la signature de [decode]/
  /// [encode]. `ZcrudRegistry()` **sans** contexte se comporte **exactement**
  /// comme sans ce câblage (rétro-compat prouvée par test).
  // Le slot est PRIVÉ (`_decodeContext`) mais exposé en paramètre NOMMÉ public
  // (`decodeContext`) : Dart interdit un formal d'initialisation nommé privé
  // (`this._decodeContext`), l'assignation en liste est donc la SEULE forme.
  ZcrudRegistry({ZDecodeContext? decodeContext})
      // ignore: prefer_initializing_formals
      : _decodeContext = decodeContext;

  /// Contexte de (dé)codage injecté, ou `null` (voie sans contexte).
  final ZDecodeContext? _decodeContext;

  final ZCodecRegistry<ZModelCodec> _codecs =
      ZCodecRegistry<ZModelCodec>('ZcrudRegistry');

  /// Seconde map interne `kind → List<ZFieldSpec>`. Alimentée par le
  /// paramètre optionnel [register]`.fieldSpecs`. Indépendante des codecs :
  /// un modèle peut être enregistré sans schéma (défaut `const []`).
  final Map<String, List<ZFieldSpec>> _fieldSpecs = <String, List<ZFieldSpec>>{};

  /// Table interne `Type → {kind…}` alimentée par [register] au moment où
  /// l'association est connue (avant que `T` ne soit effacé vers `Object`).
  ///
  /// Un `Set` (et non un `String` unique) : un même type **peut** être
  /// enregistré sous plusieurs `kind` (modèle partagé par deux collections) —
  /// cet usage reste permis à l'enregistrement, et l'ambiguïté est rendue
  /// **explicite** à la lecture par [kindOf] (jamais un choix silencieux).
  final Map<Type, Set<String>> _kindsByType = <Type, Set<String>>{};

  /// Enregistre le couple (dé)sérialisation typé de [kind] et, additivement,
  /// son schéma déclaratif [fieldSpecs] (projeté depuis `@ZcrudField`).
  ///
  /// Les callbacks sont **typés `T`** côté appelant (émis par le codegen) et
  /// adaptés vers `Object` en interne (cast sûr côté [toMap], le décodage
  /// produisant déjà un `T <: Object`). Collision → `throw`
  /// [ZDuplicateRegistrationError].
  ///
  /// [fieldSpecs] (défaut `const []`, **rétro-compatible** — AD-10 additif) est
  /// la projection `List<ZFieldSpec>` émise depuis `@ZcrudField` ; consommée
  /// par le moteur d'édition et le moteur de liste. Le codec est enregistré
  /// **avant** le schéma et la table `Type → kind` : une collision de [kind]
  /// laisse `_fieldSpecs` et l'association de [kindOf] inchangés.
  ///
  /// L'association `T → kind` est **retenue** au passage (elle alimente
  /// [kindOf], [encodeOf] et [decodeOf]). Enregistrer le **même type** sous
  /// deux `kind` distincts reste permis (modèle partagé par deux
  /// collections) : l'ambiguïté est alors signalée à la **lecture** par
  /// [kindOf], jamais refusée ici.
  ///
  /// [fromMapWithContext]/[toMapWithContext] (**additifs**, `null` par
  /// défaut — AD-10) portent les variantes conscientes du contexte. Émis par le
  /// générateur pour toute entité dont la factory de domaine accepte un
  /// `extensionParser` et/ou un `sourceRegistry` ; ignorés (retombée sur
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
    _kindsByType.putIfAbsent(T, () => <String>{}).add(kind);
  }

  /// Le `kind` sous lequel le type `T` a été enregistré, si l'association
  /// est **univoque**.
  ///
  /// Contrat (trois cas, exhaustif) :
  /// - `T` enregistré sous **exactement un** `kind` → retourne ce `kind` ;
  /// - `T` **jamais enregistré** sur cette instance → retourne `null`
  ///   (variante défensive, AD-10 — parallèle à [tryCodecFor]) ;
  /// - `T` enregistré sous **plusieurs** `kind` (modèle partagé par
  ///   plusieurs collections) → **`throw` [StateError]** au message nommant
  ///   le type et les `kind` en jeu : l'association n'étant pas univoque,
  ///   l'appelant doit passer par la voie **par-kind** ([encode]/[decode]
  ///   avec le `kind` explicite) — jamais un choix silencieux.
  ///
  /// `T` doit être le type **exact** passé à [register] (celui émis par le
  /// registrar généré) : la résolution se fait sur le paramètre de type
  /// statique, pas sur le type dynamique d'une instance.
  String? kindOf<T extends Object>() {
    final kinds = _kindsByType[T];
    if (kinds == null || kinds.isEmpty) return null;
    if (kinds.length > 1) {
      throw StateError(
        'ZcrudRegistry.kindOf<$T>() : le type "$T" est enregistré sous '
        '${kinds.length} kinds distincts '
        '(${kinds.map((String k) => '"$k"').join(', ')}). '
        'L\'association Type → kind n\'est pas univoque : passez par la voie '
        'par-kind — encode("<kind>", valeur) / decode("<kind>", map) — pour '
        'désigner explicitement la collection visée.',
      );
    }
    return kinds.first;
  }

  /// Résolution **stricte** de `T` vers son `kind` pour [encodeOf]/[decodeOf] :
  /// type non enregistré → [StateError] actionnable ; ambigu → [StateError]
  /// de [kindOf].
  String _kindOfStrict<T extends Object>(String operation) {
    final kind = kindOf<T>();
    if (kind == null) {
      throw StateError(
        'ZcrudRegistry.$operation<$T>() : aucun kind enregistré pour le type '
        '"$T". Vérifiez que le registrar généré de ce modèle '
        '(register<$T>("<kind>", …)) est bien appelé au bootstrap, avant '
        'tout (dé)codage — ou passez par la voie par-kind '
        '(encode/decode avec le kind explicite).',
      );
    }
    return kind;
  }

  /// Encode [value] en map via le codec du `kind` **résolu depuis `T`**
  /// (variante typée de [encode] pour un appelant générique sur `T`).
  ///
  /// Contrat d'erreur — jamais un silence :
  /// - `T` non enregistré → **`throw` [StateError]** actionnable ;
  /// - `T` enregistré sous plusieurs `kind` → **`throw` [StateError]**
  ///   nommant le type et les `kind` (contrat de [kindOf]) : utilisez
  ///   [encode] avec le `kind` explicite.
  ///
  /// Le contexte ([ZDecodeContext]) est threadé exactement comme par
  /// [encode]. `T` doit être le type exact passé à [register] (résolution
  /// statique — voir [kindOf]).
  Map<String, dynamic> encodeOf<T extends Object>(T value) =>
      encode(_kindOfStrict<T>('encodeOf'), value);

  /// Décode [map] en `T` via le codec du `kind` **résolu depuis `T`**
  /// (variante typée de [decode] pour un appelant générique sur `T`).
  ///
  /// Retourne directement un `T` (cast sûr : le codec enregistré sous ce
  /// `kind` a été construit avec un `fromMap` produisant un `T`).
  ///
  /// Contrat d'erreur — jamais un silence :
  /// - `T` non enregistré → **`throw` [StateError]** actionnable ;
  /// - `T` enregistré sous plusieurs `kind` → **`throw` [StateError]**
  ///   nommant le type et les `kind` (contrat de [kindOf]) : utilisez
  ///   [decode] avec le `kind` explicite.
  ///
  /// Le contexte ([ZDecodeContext]) est threadé exactement comme par
  /// [decode].
  T decodeOf<T extends Object>(Map<String, dynamic> map) =>
      decode(_kindOfStrict<T>('decodeOf'), map) as T;

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
  /// Si le codec porte une variante consciente du contexte
  /// (`fromMapWithContext`), le [ZDecodeContext] injecté au bootstrap y est
  /// **threadé** (résolution typée de `extension`/`source`, AD-4). Sinon —
  /// entité non extensible, ou contexte non câblé — comportement **identique** à
  /// la voie sans contexte (`fromMap` nu). La signature reste **INCHANGÉE**.
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
  /// Symétrique de [decode] — le contexte (provenance `source`) est
  /// threadé si le codec porte une variante `toMapWithContext`.
  Map<String, dynamic> encode(String kind, Object value) {
    final codec = codecFor(kind);
    final withContext = codec.toMapWithContext;
    return withContext != null
        ? withContext(value, _decodeContext)
        : codec.toMap(value);
  }
}
