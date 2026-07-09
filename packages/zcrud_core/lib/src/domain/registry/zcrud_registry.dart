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
import 'z_registry_error.dart';

/// Reconstruit un modèle depuis sa map persistée.
typedef ZFromMap = Object Function(Map<String, dynamic> map);

/// Sérialise un modèle vers sa map persistée.
typedef ZToMap = Map<String, dynamic> Function(Object value);

/// Couple de (dé)sérialisation d'un **modèle** enregistré, discriminé par
/// [kind]. Immuable (`const`), `==`/`hashCode` non requis (identité de codec).
class ZModelCodec {
  /// Construit le codec pour [kind] à partir de [fromMap]/[toMap].
  const ZModelCodec({
    required this.kind,
    required this.fromMap,
    required this.toMap,
  });

  /// Discriminant du modèle (ex. `"flashcard"`).
  final String kind;

  /// Reconstruit une instance depuis une map persistée.
  final ZFromMap fromMap;

  /// Sérialise une instance vers une map persistée.
  final ZToMap toMap;
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
  ZcrudRegistry();

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
  void register<T extends Object>(
    String kind, {
    required T Function(Map<String, dynamic> map) fromMap,
    required Map<String, dynamic> Function(T value) toMap,
    List<ZFieldSpec> fieldSpecs = const <ZFieldSpec>[],
  }) {
    _codecs.register(
      kind,
      ZModelCodec(
        kind: kind,
        fromMap: fromMap,
        toMap: (Object value) => toMap(value as T),
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
  Object decode(String kind, Map<String, dynamic> map) =>
      codecFor(kind).fromMap(map);

  /// Encode [value] en map via le codec de [kind] (**throw** si [kind] non
  /// enregistré, AD-3).
  Map<String, dynamic> encode(String kind, Object value) =>
      codecFor(kind).toMap(value);
}
