/// Base partagée des registres **ouverts** `register(kind, fromJson, toJson)`
/// (AD-4 pt.3).
///
/// origine: lex_core (module « Étude ») — `flashcard_source.dart:13`
/// (`FlashcardSource` : union `sealed` interne + variant `custom` + registre
/// pour lever la frontière inter-package qu'une `sealed` interdit). Canonique §4.
///
/// [ZTypeRegistry] (types de champ/valeur ouverts) et [ZSourceRegistry]
/// (provenance ouverte) partagent la **même mécanique** register/lookup/erreurs
/// et n'en diffèrent que par leur **espace de noms** (un `kind` côté source
/// n'entre pas en collision avec un `kind` côté type — Dev Notes #3, OQ-6 « par
/// axe »). La factorisation passe par le container `ZCodecRegistry<T>`
/// (composition, générique de **conteneur**), exposée ici via une base fine.
library;

import 'z_codec_registry.dart';
import 'z_registry_error.dart';

/// Reconstruit une valeur ouverte depuis sa map JSON.
typedef ZFromJson = Object Function(Map<String, dynamic> json);

/// Sérialise une valeur ouverte vers sa map JSON.
typedef ZToJson = Map<String, dynamic> Function(Object value);

/// Couple `fromJson`/`toJson` d'un type/provenance **ouvert**, discriminé par
/// [kind]. Immuable (`const`).
class ZValueCodec {
  /// Construit le codec pour [kind] à partir de [fromJson]/[toJson].
  const ZValueCodec({
    required this.kind,
    required this.fromJson,
    required this.toJson,
  });

  /// Discriminant de la valeur ouverte (ex. `"markdown"`, `"article"`).
  final String kind;

  /// Reconstruit une valeur depuis sa map JSON.
  final ZFromJson fromJson;

  /// Sérialise une valeur vers sa map JSON.
  final ZToJson toJson;
}

/// Base **fine** des registres ouverts. Exportée (utilisée par les tests
/// paramétrés et disponible pour une extension avancée), mais les apps hôtes
/// utilisent normalement les sous-types nommés ([ZTypeRegistry]/[ZSourceRegistry])
/// pour bénéficier d'espaces de noms distincts.
///
/// N'est **pas** une classe sérialisée (AD-4 rejette l'héritage de **classes
/// sérialisées**, pas le partage d'une base de comportement) : elle ne porte
/// aucune (dé)sérialisation propre, seulement le câblage register/lookup.
abstract class ZOpenRegistry {
  /// Initialise le container interne sous le nom logique [registryName].
  ZOpenRegistry(String registryName)
      : _codecs = ZCodecRegistry<ZValueCodec>(registryName);

  final ZCodecRegistry<ZValueCodec> _codecs;

  /// Enregistre le couple (dé)sérialisation ouvert de [kind]. Collision →
  /// **`throw`** [ZDuplicateRegistrationError].
  void register(
    String kind, {
    required ZFromJson fromJson,
    required ZToJson toJson,
  }) =>
      _codecs.register(
        kind,
        ZValueCodec(kind: kind, fromJson: fromJson, toJson: toJson),
      );

  /// `true` si un codec est enregistré pour [kind].
  bool isRegistered(String kind) => _codecs.isRegistered(kind);

  /// Les `kind` actuellement enregistrés.
  Iterable<String> get kinds => _codecs.kinds;

  /// Lookup **strict** : le [ZValueCodec] de [kind], ou **`throw`**
  /// [ZUnregisteredTypeError] si absent (AD-3).
  ZValueCodec codecFor(String kind) => _codecs.entryFor(kind);

  /// Lookup **défensif** : le [ZValueCodec] de [kind], ou `null` si absent
  /// (AD-10).
  ZValueCodec? tryCodecFor(String kind) => _codecs.tryEntryFor(kind);
}
