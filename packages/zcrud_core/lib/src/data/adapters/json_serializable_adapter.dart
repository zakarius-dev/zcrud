/// Adaptateur d'un modèle `@JsonSerializable` **existant** vers le
/// [ZcrudRegistry], SANS le repasser par le builder zcrud.
///
/// zcrud NE DOIT imposer ni `freezed` ni un mécanisme de réflexion. Cet
/// adaptateur se construit à partir des fonctions que le modèle possède
/// **déjà** (`fromJson`/`toJson` émis par `json_serializable`) : aucune
/// annotation `@ZcrudModel`, aucun `build_runner` zcrud, aucun `.g.dart`
/// zcrud n'est requis (seul le `.g.dart` `json_serializable` du modèle, s'il
/// existe, est utilisé — via les fonctions injectées).
///
/// **Aucune dépendance `freezed`/réflexion** n'est ajoutée à `zcrud_core` :
/// l'adaptateur ne connaît que des `Function` pures (invariant AD-3 :
/// `freezed` non imposé). Pur-Dart (couche `data`).
library;

import '../../domain/edition/z_field_spec.dart';
import 'z_model_adapter.dart';

/// Expose un modèle `@JsonSerializable` [T] comme `ZcrudModel` enregistrable.
///
/// Construit depuis les fonctions **fournies** par le modèle hérité :
/// - [fromJson] : `T Function(Map<String, dynamic>)` (factory `.fromJson`) ;
/// - [toJson]   : `Map<String, dynamic> Function(T)` (méthode `.toJson`) ;
/// - [kind]     : discriminant persistant ;
/// - [fieldSpecs] : schéma déclaratif éventuel (défaut `const []`, FOURNI — pas
///   inféré : la réutilisation ne porte que sur la sérialisation).
///
/// `registerInto(registry)` (hérité) rend [kind] décodable/encodable via
/// `registry.decode/encode`. Le mode **défensif** (invariant AD-10) est
/// offert par [fromMapSafe] (hérité) : une map corrompue devient `null` au
/// lieu de faire remonter l'exception de parsing du modèle (jamais de
/// corruption silencieuse d'une map valide).
class JsonSerializableAdapter<T extends Object> extends ZModelAdapter<T> {
  /// Construit l'adaptateur à partir des `fromJson`/`toJson` du modèle existant.
  ///
  /// Formelles initialisantes **privées** : l'argument externe reste nommé
  /// `fromJson`/`toJson` (Dart retire le `_` du nom externe), sans exposer les
  /// champs internes `_fromJson`/`_toJson`.
  JsonSerializableAdapter({
    required this.kind,
    required this._fromJson,
    required this._toJson,
    this.fieldSpecs = const <ZFieldSpec>[],
  });

  @override
  final String kind;

  @override
  final List<ZFieldSpec> fieldSpecs;

  final T Function(Map<String, dynamic> json) _fromJson;
  final Map<String, dynamic> Function(T value) _toJson;

  /// **Strict** (défaut) : délègue au `fromJson` du modèle. Peut lever sur une
  /// map corrompue ; pour un décodage tolérant utiliser [fromMapSafe]
  /// (invariant AD-10).
  @override
  T fromMap(Map<String, dynamic> map) => _fromJson(map);

  @override
  Map<String, dynamic> toMap(T value) => _toJson(value);
}
