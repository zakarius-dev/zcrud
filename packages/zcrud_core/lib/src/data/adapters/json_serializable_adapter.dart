/// Adaptateur d'un modèle `@JsonSerializable` **existant** (cible lex_douane)
/// vers le [ZcrudRegistry], SANS le repasser par le builder zcrud (FR-11).
///
/// origine: canonique §21/§252 — « lex = `json_serializable` code-gen only,
/// reflectable totalement absent ; zcrud NE DOIT imposer ni `freezed` ni
/// `reflectable` ». Cet adaptateur se construit à partir des fonctions que le
/// modèle possède **déjà** (`fromJson`/`toJson` émis par `json_serializable`) :
/// aucune annotation `@ZcrudModel`, aucun `build_runner` zcrud, aucun `.g.dart`
/// zcrud n'est requis (seul le `.g.dart` `json_serializable` du modèle, s'il
/// existe, est utilisé — via les fonctions injectées).
///
/// **Aucune dépendance `freezed`/`reflectable`** n'est ajoutée à `zcrud_core` :
/// l'adaptateur ne connaît que des `Function` pures (AD-3 : freezed non imposé).
/// Pur-Dart (couche `data`) — garde `domain_purity_test.dart`.
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
///   inféré : FR-11 est borné à la sérialisation).
///
/// `registerInto(registry)` (hérité) rend [kind] décodable/encodable via
/// `registry.decode/encode`. Le mode **défensif** (AD-10) est offert par
/// [fromMapSafe] (hérité) : une map corrompue devient `null` au lieu de faire
/// remonter l'exception de parsing du modèle (jamais de corruption silencieuse
/// d'une map valide).
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
  /// map corrompue ; pour un décodage tolérant utiliser [fromMapSafe] (AD-10).
  @override
  T fromMap(Map<String, dynamic> map) => _fromJson(map);

  @override
  Map<String, dynamic> toMap(T value) => _toJson(value);
}
