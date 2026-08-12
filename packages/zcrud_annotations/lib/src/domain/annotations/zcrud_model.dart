import 'package:zcrud_core/edition.dart';

/// Annotation de **classe** déclarant un modèle `zcrud` sérialisable et
/// enregistrable (source unique de vérité — invariant AD-3).
///
/// Le générateur `zcrud_generator` (`build_runner`) lit cette annotation
/// **statiquement** (`TypeChecker`/`ConstantReader`, jamais d'exécution ni de
/// réflexion — invariant AD-3, `reflectable` banni) pour émettre
/// `toMap`/`fromMap`/`copyWith`, le `ZFieldSpec[]` et l'enregistrement au
/// `ZcrudRegistry`.
///
/// Classe `const` **pur-données** (tous champs `final`, zéro comportement).
///
/// ---
///
/// # CONTRAT OBLIGATOIRE — un décodeur de DOMAINE `fromMap`
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
/// **Classe `ZExtensible`** (slot `extra`, invariant AD-4) : cette délégation
/// est **INTERDITE** — `_$XxxFromMap` ne connaît QUE les champs `@ZcrudField`
/// et laisse `extra` **VIDE**. Un store câblé sur `registry.decode` effacerait
/// alors **toute clé métier inconnue du schéma**, à chaque cycle
/// lecture → écriture, **irréversiblement**. La factory doit peupler `extra`,
/// et le `toMap()` d'instance doit le **réémettre** :
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
///     ...ZSyncMeta.reservedKeys,
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
/// ## Ce contrat est vérifié par la chaîne d'outillage — trois filets
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
///
/// ---
///
/// # Quels champs sont sérialisés
///
/// **Seuls les champs annotés** `@ZcrudField` (ou `@ZcrudId`) entrent dans le
/// code émis. Un champ sans annotation n'apparaît ni dans `toMap()`, ni dans le
/// décodeur, ni dans le `ZFieldSpec[]` : c'est ainsi qu'un modèle garde des
/// champs d'exécution hors persistance.
///
/// Cette omission est **refusée par le build** dans le seul cas où elle coûte
/// des données : un champ non annoté dont le **type n'est pas sérialisable**
/// (ni scalaire supporté, ni `enum`, ni classe `@ZcrudModel`). Le type désigne
/// alors un sous-objet métier, qu'une sérialisation écrite à la main émettait
/// presque toujours ; le remplacer par le code émis l'effacerait du document à
/// la première écriture, sans erreur de build ni d'analyse. Trois remèdes, tous
/// explicites : annoter le champ, annoter son type `@ZcrudModel`, ou déclarer
/// l'exclusion avec `@ZcrudIgnore` (voir `ZcrudIgnore`).
///
/// ---
///
/// # Clés de synchronisation : pourquoi `updated_at` peut manquer
///
/// Les clés `updated_at` et `is_deleted` appartiennent à la **couche de
/// synchronisation**, hors-entité (`ZSyncMeta`) : c'est elle qui les écrit et
/// les fait autorité. Un modèle peut néanmoins en porter un **miroir** (un champ
/// dont la clé persistée tombe sur l'une d'elles).
///
/// Pour ces clés-là, et pour elles seules, `toMap()` **omet la clé quand la
/// valeur est nulle** :
///
/// ```dart
/// 'created_at': this.createdAt?.toIso8601String(),                   // toujours émise
/// if (this.updatedAt != null) 'updated_at': ...,                     // clé réservée
/// ```
///
/// L'asymétrie n'a rien à voir avec le type `DateTime?` : `created_at` est une
/// clé métier ordinaire, `updated_at` une clé réservée. Émettre `updated_at:
/// null` inconditionnellement ferait signaler une collision avec la couche de
/// sync à **chaque** écriture de **chaque** entité concernée, sans qu'aucun de
/// ces cas ne porte de signal. La clé **non nulle**, elle, reste émise : le
/// round-trip `fromMap(toMap(x))` doit rester fidèle pour un miroir renseigné.
///
/// Sur un backend où « clé absente » et « clé à `null` » ne sont pas
/// équivalents (requêtes sur nullité, sémantique d'absence), c'est cette
/// distinction qu'il faut avoir en tête : ne pas dériver l'état de
/// synchronisation d'un miroir, mais des métadonnées `ZSyncMeta`.
///
/// ---
///
/// # Le `toMap()` généré n'est pas destiné à une écriture directe
///
/// Le code émis sérialise **toute** date en `String` ISO-8601. Le format natif
/// d'un backend (par exemple `Timestamp` côté Firestore) est appliqué par le
/// **repository**, à partir de la métadonnée neutre `$XxxTimestampFields` — le
/// type natif reste confiné à son adaptateur (invariant AD-5). Un moteur de
/// persistance qui appellerait `toMap()` directement, sans passer par le
/// repository, écrirait donc des `String` là où le parc attend le type natif :
/// point d'attention réel en migration progressive, quand un chemin d'écriture
/// hérité cohabite avec le chemin zcrud.
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
