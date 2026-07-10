/// Entité canonique `ZFlashcard` (Story E9-1, AC3/AC4/AC5/AC7).
///
/// origine: lex_core (module « Étude ») — `flashcard.dart:37`, modèle le plus
/// abouti, schéma canonique zéro-perte partagé chat LexIA ↔ éducation
/// (canonique §2.1).
///
/// **Généré par `@ZcrudModel` (AD-3)** : `melos run generate` émet
/// `z_flashcard.g.dart` (`part`, gitignoré, régénéré) portant `_$…FromMap`,
/// l'extension `ZFlashcardZcrud` (`toMap`/`copyWith`), `$ZFlashcardFieldSpecs`
/// et `registerZFlashcard(ZcrudRegistry)`.
///
/// **État SRS HORS carte (AD-9)** : `ZFlashcard` ne porte AUCUN champ SRS
/// (`interval`/`repetitions`/`easeFactor`/`nextReviewDate`/`learnedAt`/
/// `lastQuality`/`ZRepetitionInfo`). L'état SRS vit dans une entité séparée
/// (E9-2), persistée top-level (E9-4). Le partage/duplication d'une carte
/// n'emporte donc **jamais** l'historique d'autrui.
///
/// **Slots d'extension AD-4** : mixe `ZExtensible` (cœur) → `extra`
/// (échappatoire non typée, round-trip des clés inconnues) + `extension`
/// (slot type additif versionné, parsé défensivement). Ces trois canaux
/// (`source`, `extension`, `extra`) NE sont PAS gérés par le générateur (types
/// non (dé)sérialisables par codegen) : ils sont **câblés manuellement** autour
/// du code généré dans [ZFlashcard.fromMap]/[toMap]/[copyWith].
///
/// **Éphémère (AD-14)** : `isEphemeral` provient de `ZEntity` (dérivé de
/// `id == null`). L'entité n'attribue jamais d'`id` ; la matérialisation
/// (attribution avant écriture) est portée par le repository (E9-4), hors
/// périmètre ici.
///
/// Réutilise le cœur via `package:zcrud_core/zcrud_core.dart` (`ZEntity`,
/// `ZExtensible`, `ZExtension`, `ZSourceRegistry`, `ZFieldSpec`, `ZcrudRegistry`)
/// — même convention d'import que `zcrud_mindmap` ; testé via `flutter test`.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_choice.dart';
import 'z_flashcard_source.dart';
import 'z_flashcard_type.dart';

export 'z_choice.dart';
export 'z_flashcard_source.dart';
export 'z_flashcard_type.dart';

part 'z_flashcard.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
///
/// Fourni par l'app/le satellite (convention `X.fromJsonSafe`) et injecté dans
/// [ZFlashcard.fromMap] : le cœur ne connaît pas les sous-classes concrètes
/// (AD-4). Toute exception est absorbée en `null` par [ZExtension.guard]
/// (AD-10), le parent survivant toujours.
typedef ZFlashcardExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Flashcard canonique immuable (données + `copyWith` ; invariants au repo).
@ZcrudModel(kind: 'flashcard')
class ZFlashcard extends ZEntity with ZExtensible {
  /// Construit une flashcard (constructeur nommé — source du `copyWith`).
  const ZFlashcard({
    this.id,
    this.folderId,
    this.subFolderId,
    this.type = ZFlashcardType.openQuestion,
    required this.question,
    this.answer,
    this.isTrue,
    this.choices,
    this.explanation,
    this.hint,
    this.tagIds = const <String>[],
    this.isReadOnly = false,
    this.createdAt,
    this.updatedAt,
    this.source,
    this.extension,
    this.extra = const <String, dynamic>{},
  });

  /// Reconstruit **défensivement** depuis une map persistée (AD-10).
  ///
  /// Délègue au `_$ZFlashcardFromMap` **généré** (champs scalaires/enum/sous-
  /// modèles : défauts sûrs, `type` inconnu → `openQuestion`, `choices`
  /// malformés décodés élément par élément), puis **câble manuellement** les
  /// trois canaux hors-codegen :
  /// - [source] via [ZFlashcardSource.fromJson] (consulte [sourceRegistry]) ;
  /// - [extension] via [extensionParser] (repli `null`, `ZExtension.guard`) ;
  /// - [extra] = clés **non réservées** de la map (round-trip préservé).
  ///
  /// Aucun cas ne fait échouer le parent (map vide, `source`/`extension`
  /// corrompus, `tag_ids` absent…).
  factory ZFlashcard.fromMap(
    Map<String, dynamic> map, {
    ZSourceRegistry? sourceRegistry,
    ZFlashcardExtensionParser? extensionParser,
  }) {
    final base = _$ZFlashcardFromMap(map);
    return ZFlashcard(
      id: base.id,
      folderId: base.folderId,
      subFolderId: base.subFolderId,
      type: base.type,
      question: base.question,
      answer: base.answer,
      isTrue: base.isTrue,
      choices: base.choices,
      explanation: base.explanation,
      hint: base.hint,
      tagIds: base.tagIds,
      isReadOnly: base.isReadOnly,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      source: ZFlashcardSource.fromJson(map['source'], registry: sourceRegistry),
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère — AC5).
  @override
  @ZcrudId()
  final String? id;

  /// Dossier d'appartenance (clé de partitionnement).
  @ZcrudField()
  final String? folderId;

  /// Sous-dossier (hiérarchie 2 niveaux).
  @ZcrudField()
  final String? subFolderId;

  /// Type canonique (défaut/repli défensif `openQuestion` — AC1).
  @ZcrudField(defaultValue: ZFlashcardType.openQuestion)
  final ZFlashcardType type;

  /// Énoncé (recto) — **seul champ texte requis** (validateur éditeur).
  @ZcrudField(
    label: 'Question',
    validators: <ZValidatorSpec>[ZValidatorSpec.required()],
  )
  final String question;

  /// Réponse libre (openQuestion/exercise/fillBlank/shortAnswer).
  @ZcrudField()
  final String? answer;

  /// Réponse de type vrai/faux.
  @ZcrudField()
  final bool? isTrue;

  /// Options QCM (validation min 2 + 1 correct **déférée** à E9-5).
  @ZcrudField()
  final List<ZChoice>? choices;

  /// Explication pédagogique post-réponse.
  @ZcrudField()
  final String? explanation;

  /// Indice.
  @ZcrudField()
  final String? hint;

  /// Étiquettes (défaut `const []` ; filtrage de session).
  @ZcrudField()
  final List<String> tagIds;

  /// Carte issue d'un partage (lecture seule), défaut `false`.
  @ZcrudField()
  final bool isReadOnly;

  /// Date de création (ISO-8601 ; `null` si éphémère).
  @ZcrudField()
  final DateTime? createdAt;

  /// Date de mise à jour (ISO-8601 ; clé de merge LWW).
  @ZcrudField()
  final DateTime? updatedAt;

  /// Provenance polymorphe **ouverte** (variant « article » via registre — AC6).
  ///
  /// Hors-codegen : (dé)sérialisée manuellement via [ZFlashcardSource].
  final ZFlashcardSource? source;

  /// Slot type additif **versionné** (AD-4 pt.1), `null` si absent. Hors-codegen.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (AD-4 pt.2), défaut `const {}` (jamais `null`),
  /// préservant les clés inconnues du cœur au round-trip. Hors-codegen.
  @override
  final Map<String, dynamic> extra;

  /// Sérialise vers la map persistée **complète** (snake_case).
  ///
  /// Réutilise le `toMap()` **généré** (champs scalaires/enum/sous-modèles) puis
  /// ajoute les trois canaux hors-codegen : [extra] (clés inconnues préservées),
  /// [source] (via [sourceRegistry]) et [extension]. Le `registerZFlashcard`
  /// généré appelle ce `toMap()` (il masque l'extension générée).
  Map<String, dynamic> toMap({ZSourceRegistry? sourceRegistry}) {
    final map = <String, dynamic>{
      ...extra,
      ...ZFlashcardZcrud(this).toMap(),
    };
    if (source != null) {
      map['source'] = source!.toJson(registry: sourceRegistry);
    }
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie avec sentinelle (un argument omis préserve la valeur, `null` explicite
  /// la remet à `null`). Couvre **tous** les champs, y compris [source],
  /// [extension] et [extra] (que le `copyWith` généré ignore, faute
  /// d'annotation) — évite toute perte silencieuse.
  ZFlashcard copyWith({
    Object? id = _$undefined,
    Object? folderId = _$undefined,
    Object? subFolderId = _$undefined,
    Object? type = _$undefined,
    Object? question = _$undefined,
    Object? answer = _$undefined,
    Object? isTrue = _$undefined,
    Object? choices = _$undefined,
    Object? explanation = _$undefined,
    Object? hint = _$undefined,
    Object? tagIds = _$undefined,
    Object? isReadOnly = _$undefined,
    Object? createdAt = _$undefined,
    Object? updatedAt = _$undefined,
    Object? source = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) =>
      ZFlashcard(
        id: identical(id, _$undefined) ? this.id : id as String?,
        folderId:
            identical(folderId, _$undefined) ? this.folderId : folderId as String?,
        subFolderId: identical(subFolderId, _$undefined)
            ? this.subFolderId
            : subFolderId as String?,
        type: identical(type, _$undefined) ? this.type : type as ZFlashcardType,
        question: identical(question, _$undefined)
            ? this.question
            : question as String,
        answer: identical(answer, _$undefined) ? this.answer : answer as String?,
        isTrue: identical(isTrue, _$undefined) ? this.isTrue : isTrue as bool?,
        choices: identical(choices, _$undefined)
            ? this.choices
            : choices as List<ZChoice>?,
        explanation: identical(explanation, _$undefined)
            ? this.explanation
            : explanation as String?,
        hint: identical(hint, _$undefined) ? this.hint : hint as String?,
        tagIds: identical(tagIds, _$undefined)
            ? this.tagIds
            : tagIds as List<String>,
        isReadOnly: identical(isReadOnly, _$undefined)
            ? this.isReadOnly
            : isReadOnly as bool,
        createdAt: identical(createdAt, _$undefined)
            ? this.createdAt
            : createdAt as DateTime?,
        updatedAt: identical(updatedAt, _$undefined)
            ? this.updatedAt
            : updatedAt as DateTime?,
        source: identical(source, _$undefined)
            ? this.source
            : source as ZFlashcardSource?,
        extension: identical(extension, _$undefined)
            ? this.extension
            : extension as ZExtension?,
        extra: identical(extra, _$undefined)
            ? this.extra
            : extra as Map<String, dynamic>,
      );

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZFlashcardExtensionParser? parser,
  ) {
    if (parser == null) return null;
    final map = _asStringMap(raw);
    if (map == null) return null;
    return ZExtension.guard<ZExtension?>(() => parser(map));
  }

  /// Clés persistées **réservées** (champs générés + `source` + `extension`) —
  /// dérivées de `$ZFlashcardFieldSpecs` pour rester synchrones avec le codegen.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZFlashcardFieldSpecs) spec.name,
    'source',
    'extension',
  };

  /// Extrait `extra` = clés non réservées de [map] (round-trip préservé).
  /// Rendu **non-modifiable** (cohérence `ZExtensible`/`ZCustomSource.payload`).
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      Map<String, dynamic>.unmodifiable(<String, dynamic>{
        for (final e in map.entries)
          if (!_reservedKeys.contains(e.key)) e.key: e.value,
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFlashcard &&
          id == other.id &&
          folderId == other.folderId &&
          subFolderId == other.subFolderId &&
          type == other.type &&
          question == other.question &&
          answer == other.answer &&
          isTrue == other.isTrue &&
          _listEquals(choices, other.choices) &&
          explanation == other.explanation &&
          hint == other.hint &&
          _listEquals(tagIds, other.tagIds) &&
          isReadOnly == other.isReadOnly &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          source == other.source &&
          extension == other.extension &&
          _mapEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        folderId,
        subFolderId,
        type,
        question,
        answer,
        isTrue,
        if (choices != null) Object.hashAll(choices!),
        explanation,
        hint,
        Object.hashAll(tagIds),
        isReadOnly,
        createdAt,
        updatedAt,
        source,
        extension,
        _mapHash(extra),
      ]);
}

/// Coerce défensive vers `Map<String, dynamic>` (repli `null`).
Map<String, dynamic>? _asStringMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    try {
      return <String, dynamic>{for (final e in v.entries) '${e.key}': e.value};
    } catch (_) {
      return null;
    }
  }
  return null;
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
  }
  return true;
}

int _mapHash(Map<String, dynamic> m) {
  var h = 0;
  for (final e in m.entries) {
    h ^= Object.hash(e.key, e.value);
  }
  return h;
}
