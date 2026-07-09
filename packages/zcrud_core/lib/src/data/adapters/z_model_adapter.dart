/// Contrat d'**adaptation d'un modèle EXISTANT** vers le [ZcrudRegistry] (FR-11).
///
/// origine: FR-11 « réutiliser l'existant sans réécrire » (canonique §246) —
/// zcrud « expose des contrats abstraits + un registre, et laisse chaque app
/// choisir sa techno de génération ». `ZModelAdapter` est le **pont** entre le
/// codegen natif zcrud (E2-5, `@ZcrudModel` + build_runner) et les modèles
/// hérités qui possèdent DÉJÀ leur (dé)sérialisation : un modèle
/// `@JsonSerializable` (lex_douane, via [JsonSerializableAdapter]) ou un modèle
/// `reflectable` (DODLP, via `ReflectableCodec` dans `zcrud_get`).
///
/// **Nommage (Ambiguïté #1, tranchée)** : `ZModelAdapter` — PAS `ZCodec`.
/// `ZCodec` est réservé par AD-7 au codec **rich-text** pluggable
/// (Delta/Markdown/HTML, E6-2). Ici on adapte des **modèles**, d'où
/// `ZModelAdapter` ; les impls concrètes gardent les noms du backlog
/// (`JsonSerializableAdapter`, `ReflectableCodec`).
///
/// **Pur-Dart (couche `data`, AD-1)** : ce fichier n'importe ni Flutter, ni
/// Firebase, ni `reflectable`, ni un gestionnaire d'état — la garde
/// `domain_purity_test.dart` couvre déjà `lib/src/data`.
library;

import '../../domain/edition/z_field_spec.dart';
import '../../domain/registry/zcrud_registry.dart';

/// Adapte un modèle **existant** de type [T] (non-null, `T extends Object`) au
/// [ZcrudRegistry] : il en **enveloppe** la (dé)sérialisation propre au lieu de
/// la réécrire ou de la repasser par le builder zcrud (FR-11).
///
/// Un adaptateur expose le triplet minimal qu'attend le registre —
/// [kind]/[fromMap]/[toMap] — plus les [fieldSpecs] éventuels (FOURNIS, jamais
/// inférés du modèle hérité : FR-11 est borné à la réutilisation de la
/// *sérialisation*, pas à la reconstruction du schéma de formulaire). La méthode
/// [registerInto] branche le tout sur une **instance** de [ZcrudRegistry]
/// (injectée au bootstrap — cf. E7-2 DODLP / E8-1 lex).
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
  /// Transmis tel quel à `registry.register` (E3/E4 le consomment ; enregistrer
  /// sans schéma est licite : `fieldSpecsFor(kind)` renvoie alors `const []`).
  List<ZFieldSpec> get fieldSpecs;

  /// Décodage **défensif** (AD-10) : enveloppe [fromMap] et renvoie `null` au
  /// lieu de propager une exception de parsing au-delà de la frontière
  /// d'adaptation. Aligné sur la convention E2-5 (`fromJsonSafe → null`).
  ///
  /// **Ne corrompt jamais silencieusement** une map valide : une map valide
  /// produit exactement le même résultat que [fromMap] ; seule une map
  /// corrompue/tronquée (qui aurait levé) devient `null`. Le [ZcrudRegistry]
  /// enregistre la voie **stricte** ([fromMap], non-null par contrat) ; un
  /// appelant tolérant (repository E5) peut invoquer [fromMapSafe] directement.
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
  /// (signature E2-3 **gelée**). Collision de [kind] →
  /// `ZDuplicateRegistrationError` (contrat E2-3 préservé). Voie stricte
  /// enregistrée (le registre exige un décodage non-null).
  void registerInto(ZcrudRegistry registry) {
    registry.register<T>(
      kind,
      fromMap: fromMap,
      toMap: toMap,
      fieldSpecs: fieldSpecs,
    );
  }
}
