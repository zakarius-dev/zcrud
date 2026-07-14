import 'package:zcrud_core/edition.dart';

/// Annotation de **classe** déclarant un modèle `zcrud` sérialisable et
/// enregistrable (source unique de vérité — AD-3).
///
/// Le générateur E2-5 (`build_runner`) lit cette annotation **statiquement**
/// (`TypeChecker`/`ConstantReader`, jamais d'exécution ni de réflexion — AD-3,
/// `reflectable` banni) pour émettre `toMap`/`fromMap`/`copyWith`, le
/// `ZFieldSpec[]` et l'enregistrement au `ZcrudRegistry`.
///
/// Classe `const` **pur-données** (tous champs `final`, zéro comportement — AC1).
///
/// ---
///
/// # ⚠️ CONTRAT OBLIGATOIRE — un décodeur de DOMAINE `fromMap`
///
/// > **CHANGEMENT CASSANT** pour tout modèle existant qui n'en déclare pas —
/// > cf. `zcrud_generator/CHANGELOG.md` (note de migration).
///
/// Toute classe `@ZcrudModel` **DOIT** déclarer
/// `Xxx.fromMap(Map<String, dynamic> map)` — **factory** ou **méthode statique**,
/// avec autant de paramètres **optionnels** supplémentaires qu'on veut. C'est
/// **elle** que le registrar généré câble (`fromMap: Xxx.fromMap`).
///
/// **Son absence est un ÉCHEC DE BUILD**, jamais un repli silencieux.
///
/// ## Deux formes, selon que la classe est `ZExtensible` ou non
///
/// **Classe SANS slot `extra`** (value object — patron `ZChoice`) : la délégation
/// nue au décodeur du codegen suffit.
///
/// ```dart
/// @ZcrudModel(kind: 'flashcard_choice')
/// class ZChoice {
///   factory ZChoice.fromMap(Map<String, dynamic> map) => _$ZChoiceFromMap(map);
/// }
/// ```
///
/// **Classe `ZExtensible`** (slot `extra`, AD-4) : cette délégation est
/// **INTERDITE** — `_$XxxFromMap` ne connaît QUE les champs `@ZcrudField` et
/// laisse `extra` **VIDE**. Un store câblé sur `registry.decode` effacerait alors
/// **toute clé métier inconnue du schéma**, à chaque cycle lecture → écriture,
/// **irréversiblement** (dette DW-ES14-1). La factory doit peupler `extra`, et le
/// `toMap()` d'instance doit le **réémettre** :
///
/// ```dart
/// @ZcrudModel(kind: 'flashcard')
/// class ZFlashcard with ZExtensible {
///   factory ZFlashcard.fromMap(Map<String, dynamic> map) {
///     final base = _$ZFlashcardFromMap(map);          // champs du schéma
///     return ZFlashcard(
///       /* …champs recopiés depuis `base`… */
///       extra: _extraFrom(map),                       // ✅ clés HORS-schéma
///     );
///   }
///
///   /// Masque le `toMap()` GÉNÉRÉ, qui n'étale PAS `extra`.
///   Map<String, dynamic> toMap() => {...extra, ...ZFlashcardZcrud(this).toMap()};
///
///   static final Set<String> _reservedKeys = <String>{
///     for (final spec in $ZFlashcardFieldSpecs) spec.name,
///     ...ZSyncMeta.reservedKeys,                      // AD-19.1
///   };
///
///   static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
///       Map<String, dynamic>.unmodifiable({
///         for (final e in map.entries)
///           if (!_reservedKeys.contains(e.key)) e.key: e.value,
///       });
/// }
/// ```
///
/// ## Ce contrat est vérifié PAR MACHINE — trois filets
///
/// 1. **BUILD** : décodeur absent, ou signature incompatible ⇒
///    `InvalidGenerationSourceError`.
/// 2. **BUILD** : classe `ZExtensible` dont le `fromMap` **délègue nuement** à
///    `_$XxxFromMap` ⇒ `InvalidGenerationSourceError` (c'est *littéralement* la
///    destruction d'`extra`).
/// 3. **RUNTIME** : le `registerXxx` généré d'une classe `ZExtensible` porte un
///    **garde exécutoire** qui décode une sonde et exige que la clé hors-schéma
///    **survive au round-trip complet** (`fromMap` **et** `toMap`). Il lève un
///    `StateError` explicite à l'enregistrement. Il n'est **pas** sous `assert` :
///    le filet doit tenir en release, là où la perte est définitive.
///
/// ```dart
/// @ZcrudModel(kind: 'article')
/// class Article {
///   factory Article.fromMap(Map<String, dynamic> map) => _$ArticleFromMap(map);
///   ...
/// }
/// ```
class ZcrudModel {
  /// Construit l'annotation `const` avec des défauts sûrs.
  const ZcrudModel({this.kind, this.fieldRename = ZFieldRename.snake});

  /// Discriminant du `ZcrudRegistry`. `null` ⇒ le générateur E2-5 le **dérive**
  /// du nom de la classe.
  final String? kind;

  /// Stratégie de renommage des clés persistées (défaut [ZFieldRename.snake] —
  /// AD-3, persistance snake_case). Un `@ZcrudField.name` explicite prime.
  final ZFieldRename fieldRename;
}
