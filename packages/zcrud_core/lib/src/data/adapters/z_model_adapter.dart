/// Contrat d'**adaptation d'un modèle EXISTANT** vers le [ZcrudRegistry].
///
/// zcrud expose des contrats abstraits et un registre, et laisse chaque
/// application choisir sa propre technologie de génération. `ZModelAdapter`
/// est le **pont** entre le codegen natif zcrud (`@ZcrudModel` +
/// build_runner) et les modèles hérités qui possèdent DÉJÀ leur
/// (dé)sérialisation : un modèle `@JsonSerializable` (via
/// [JsonSerializableAdapter]) ou un modèle sérialisé par un mécanisme de
/// réflexion propre à l'application hôte (via un adaptateur dédié fourni par
/// le binding correspondant).
///
/// **Nommage** : `ZModelAdapter` — PAS `ZCodec`. `ZCodec` est réservé par
/// l'invariant AD-7 au codec **rich-text** pluggable (Delta/Markdown/HTML).
/// Ici on adapte des **modèles**, d'où `ZModelAdapter` ; les implémentations
/// concrètes gardent des noms qui reflètent leur mécanisme
/// (`JsonSerializableAdapter`, `ReflectableCodec`).
///
/// **Pur-Dart (couche `data`, invariant AD-1)** : ce fichier n'importe ni
/// Flutter, ni Firebase, ni un mécanisme de réflexion, ni un gestionnaire
/// d'état.
library;

import '../../domain/edition/z_field_spec.dart';
import '../../domain/registry/zcrud_registry.dart';

/// Adapte un modèle **existant** de type [T] (non-null, `T extends Object`) au
/// [ZcrudRegistry] : il en **enveloppe** la (dé)sérialisation propre au lieu de
/// la réécrire ou de la repasser par le builder zcrud.
///
/// Un adaptateur expose le triplet minimal qu'attend le registre —
/// [kind]/[fromMap]/[toMap] — plus les [fieldSpecs] éventuels (FOURNIS, jamais
/// inférés du modèle hérité : la réutilisation ne porte que sur la
/// *sérialisation*, pas sur la reconstruction du schéma de formulaire). La
/// méthode [registerInto] branche le tout sur une **instance** de
/// [ZcrudRegistry] (injectée au bootstrap par l'application hôte).
abstract class ZModelAdapter<T extends Object> {
  /// Discriminant persistant du modèle (ex. `"etude"`, `"flashcard"`).
  String get kind;

  /// Reconstruit une instance [T] (non-null) depuis sa [map] persistée.
  ///
  /// **Mode strict** (défaut) : délègue à la (dé)sérialisation du modèle hérité
  /// et **peut lever** sur une map corrompue. Pour un décodage tolérant à la
  /// frontière (AD-10), voir [fromMapSafe].
  T fromMap(Map<String, dynamic> map);

  /// Sérialise [value] vers sa map persistée (via la sérialisation du modèle).
  Map<String, dynamic> toMap(T value);

  /// Schéma déclaratif éventuel (défaut `const []`) — **fourni**, pas inféré.
  /// Transmis tel quel à `registry.register` (consommé par le moteur
  /// d'édition et le moteur de liste ; enregistrer sans schéma est licite :
  /// `fieldSpecsFor(kind)` renvoie alors `const []`).
  List<ZFieldSpec> get fieldSpecs;

  /// Décodage **défensif** (invariant AD-10) : enveloppe [fromMap] et renvoie
  /// `null` au lieu de propager une exception de parsing au-delà de la
  /// frontière d'adaptation, conformément à la convention `fromJsonSafe →
  /// null`.
  ///
  /// **Ne corrompt jamais silencieusement** une map valide : une map valide
  /// produit exactement le même résultat que [fromMap] ; seule une map
  /// corrompue/tronquée (qui aurait levé) devient `null`. Le [ZcrudRegistry]
  /// enregistre la voie **stricte** ([fromMap], non-null par contrat) ; un
  /// appelant tolérant (un repository offline-first) peut invoquer
  /// [fromMapSafe] directement.
  T? fromMapSafe(Map<String, dynamic> map) {
    try {
      return fromMap(map);
    } on Object {
      return null;
    }
  }

  /// Enregistre cet adaptateur dans [registry] : rend [kind] décodable/encodable
  /// via `registry.decode/encode(kind, …)` et publie [fieldSpecs].
  ///
  /// Délègue à `registry.register<T>(kind, fromMap:, toMap:, fieldSpecs:)`
  /// (signature **gelée**). Collision de [kind] →
  /// `ZDuplicateRegistrationError`. Voie stricte enregistrée (le registre
  /// exige un décodage non-null).
  void registerInto(ZcrudRegistry registry) {
    registry.register<T>(
      kind,
      fromMap: fromMap,
      toMap: toMap,
      fieldSpecs: fieldSpecs,
    );
  }
}
