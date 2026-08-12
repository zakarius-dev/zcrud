/// Entité canonique `ZFlashcard` — le contenu d'une carte de révision.
///
/// Généré par `@ZcrudModel` (invariant AD-3) : le codegen émet
/// `z_flashcard.g.dart` portant le décodeur, l'extension `ZFlashcardZcrud`
/// (`toMap`/`copyWith`), les spécifications de champs et l'enregistrement au
/// registre.
///
/// ## L'état SRS vit hors de la carte
///
/// `ZFlashcard` ne porte **aucun** champ de répétition espacée (intervalle,
/// nombre de répétitions, facteur de facilité, prochaine échéance, dernière
/// qualité). Cet état vit dans une entité séparée, persistée dans son propre
/// canal (voir `ZRepetitionInfo`, invariant AD-9). Le partage ou la
/// duplication d'une carte n'emporte donc jamais l'historique de révision.
///
/// ## Slots d'extension
///
/// Mixe `ZExtensible` (invariant AD-4) : `extra` (échappatoire non typée,
/// préserve les clés inconnues au round-trip) et `extension` (emplacement
/// typé et versionné, décodé défensivement). Ces deux canaux, ainsi que
/// [source], ne sont pas gérés par le codegen (types non sérialisables par le
/// générateur) : ils sont câblés explicitement autour du code généré dans
/// [ZFlashcard.fromMap], [toMap] et [copyWith].
///
/// ## Éphémère
///
/// `isEphemeral` (hérité de `ZEntity`) est dérivé de `id == null` (invariant
/// AD-14). L'entité n'attribue jamais elle-même d'`id` ; la matérialisation
/// (attribution avant écriture) est portée par le repository.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import 'z_choice.dart';
import 'z_flashcard_source.dart';
import 'z_flashcard_type.dart';

export 'z_choice.dart';
export 'z_flashcard_source.dart';
export 'z_flashcard_type.dart';

part 'z_flashcard.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou rend `null`.
///
/// Fourni par l'application ou le satellite appelant, et injecté dans
/// [ZFlashcard.fromMap] : le domaine ne connaît pas les sous-classes
/// concrètes (invariant AD-4). Toute exception levée par le parseur est
/// absorbée en `null` par [ZExtension.guard] (invariant AD-10), le parent
/// survivant toujours.
typedef ZFlashcardExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Flashcard canonique immuable (données et `copyWith` ; les invariants
/// métier vivent au repository).
///
/// Implémente [ZSessionCandidate] : `ZFlashcard` est un candidat filtrable
/// par un sélecteur de session via ses clés neutres `folderId`/`subFolderId`/
/// `tagIds` et `typeKey` (le `name` du type, exposé comme une clé opaque
/// String) — le noyau d'étude reste ainsi ignorant de [ZFlashcardType].
@ZcrudModel(kind: 'flashcard')
class ZFlashcard extends ZEntity with ZExtensible implements ZSessionCandidate {
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
    Map<String, dynamic> extra = const <String, dynamic>{},
    // Un paramètre nommé ne peut pas être privé en Dart
    // (PRIVATE_OPTIONAL_PARAMETER) — le slot brut doit pourtant rester privé,
    // c'est l'accesseur `extra` qui porte la garde.
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement une flashcard depuis une map persistée
  /// (invariant AD-10).
  ///
  /// Délègue au décodeur généré pour les champs scalaires/enum/sous-modèles
  /// (défauts sûrs : un `type` inconnu retombe sur `openQuestion`, un choix
  /// malformé de la liste `choices` est décodé élément par élément), puis
  /// câble explicitement les trois canaux hors schéma :
  /// - [source] via [ZFlashcardSource.fromJson] (consulte [sourceRegistry]) ;
  /// - [extension] via [extensionParser] (repli `null`,
  ///   [ZExtension.guard]) ;
  /// - [extra] = les clés non réservées de la map (round-trip préservé).
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

  /// Identité opaque (`null` pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Dossier d'appartenance (clé de partitionnement ; exposée au port
  /// [ZSessionCandidate]).
  @override
  @ZcrudField()
  final String? folderId;

  /// Sous-dossier (hiérarchie à deux niveaux ; exposé au port
  /// [ZSessionCandidate]).
  @override
  @ZcrudField()
  final String? subFolderId;

  /// Type canonique de la carte (défaut et repli défensif
  /// [ZFlashcardType.openQuestion]).
  @ZcrudField(defaultValue: ZFlashcardType.openQuestion)
  final ZFlashcardType type;

  /// Énoncé (recto) — seul champ texte requis par le validateur d'édition.
  @ZcrudField(
    label: 'Question',
    validators: <ZValidatorSpec>[ZValidatorSpec.required()],
  )
  final String question;

  /// Réponse libre — pertinente pour les types question ouverte, exercice,
  /// texte à trous et réponse courte.
  @ZcrudField()
  final String? answer;

  /// Réponse attendue pour une carte de type vrai/faux.
  @ZcrudField()
  final bool? isTrue;

  /// Options d'un QCM. La validation métier (au moins deux choix, au moins un
  /// correct) est appliquée par la couche d'édition, pas par l'entité.
  @ZcrudField()
  final List<ZChoice>? choices;

  /// Explication pédagogique affichée après la réponse.
  @ZcrudField()
  final String? explanation;

  /// Indice affiché à la demande.
  @ZcrudField()
  final String? hint;

  /// Étiquettes (défaut `const []` ; utilisées pour le filtrage de session ;
  /// exposées au port [ZSessionCandidate]).
  @override
  @ZcrudField()
  final List<String> tagIds;

  /// Carte issue d'un partage, en lecture seule (défaut `false`).
  @ZcrudField()
  final bool isReadOnly;

  /// Date de création (ISO-8601 ; `null` si éphémère).
  @ZcrudField()
  final DateTime? createdAt;

  /// Date de mise à jour (ISO-8601) — miroir de compatibilité, jamais
  /// l'autorité de fusion.
  ///
  /// L'autorité Last-Write-Wins est exclusivement portée par
  /// `ZSyncMeta.updatedAt`, hors entité (invariant AD-9) : le repository
  /// délègue le merge à un résolveur qui l'utilise. Ce champ est maintenu par
  /// l'adaptateur (pour partager la même clé persistée `updated_at`) au
  /// bénéfice des lectures anciennes. Ne l'utilisez jamais pour décider d'un
  /// merge, d'un tri de synchronisation ou d'une résolution de conflit.
  @ZcrudField()
  final DateTime? updatedAt;

  /// Provenance polymorphe ouverte (un variant applicatif se branche via un
  /// registre).
  ///
  /// Hors schéma généré : (dé)sérialisée explicitement via
  /// [ZFlashcardSource].
  @ZcrudIgnore()
  final ZFlashcardSource? source;

  /// Emplacement d'extension typée et versionnée (invariant AD-4), `null` si
  /// absente. Hors schéma généré.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}` (jamais
  /// `null`), qui préserve au round-trip les clés inconnues du domaine. Hors
  /// schéma généré.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Emplacement `extra` brut tel que reçu par le constructeur — lu nulle
  /// part ailleurs que dans l'accesseur [extra] (ni `toMap`, ni `==`, ni
  /// `hashCode`).
  ///
  /// Il peut être pollué : le constructeur nominal est `const`, il ne peut
  /// appeler aucune fonction dans son initialiseur, et l'invariant AD-10
  /// interdit d'y placer un `assert`. C'est l'accesseur [extra] qui porte la
  /// garde — le seul point que toutes les voies traversent.
  final Map<String, dynamic> _extra;

  /// Clé de type opaque exposée au port [ZSessionCandidate] : le nom
  /// camelCase du [type] (par exemple `"multipleChoice"`), comparé tel quel
  /// au filtre de types d'une configuration de session. Le noyau d'étude
  /// reste ainsi ignorant de [ZFlashcardType].
  @override
  String get typeKey => type.name;

  /// Sérialise vers la map persistée complète (snake_case).
  ///
  /// Réutilise le `toMap()` généré (champs scalaires/enum/sous-modèles) puis
  /// ajoute les trois canaux hors schéma : [extra] (clés inconnues
  /// préservées), [source] (via [sourceRegistry]) et [extension].
  Map<String, dynamic> toMap({ZSourceRegistry? sourceRegistry}) {
    final map = <String, dynamic>{
      // Frontière de sortie que toutes les voies d'écriture traversent :
      // l'ordre du spread importe — le contenu généré écrase `extra`, ce qui
      // protège les champs de schéma d'une pollution de clé identique.
      // Étale l'accesseur (qui normalise), jamais le champ brut `_extra`.
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

  /// Copie à sentinelle (un argument omis préserve la valeur, `null`
  /// explicite la remet à `null`). Couvre tous les champs, y compris
  /// [source], [extension] et [extra], que le `copyWith` généré par le
  /// codegen ignore faute d'annotation — ce qui évite toute perte
  /// silencieuse.
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
        // La garde de `extra` est la même fonction nommée qu'en `fromMap` —
        // `copyWith` ne peut pas rouvrir le filtre des clés réservées. La
        // valeur écrite est toujours dépouillée des clés de synchronisation
        // (`updated_at`/`is_deleted`), qui n'ont jamais eu le droit d'y être
        // (invariant AD-9).
        extra: identical(extra, _$undefined)
            ? this.extra
            : _sanitizeExtra(extra as Map<String, dynamic>),
      );

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZFlashcardExtensionParser? parser,
  ) {
    // Un hôte sans parseur ne détruit pas le payload : comme `extension` est
    // une clé connue (donc exclue d'`extra`), le contenu d'un autre hôte est
    // préservé verbatim, quel que soit le résultat du parseur.
    return zDecodeExtension(raw, parser);
  }

  /// Clés persistées réservées (champs générés, `source`, `extension` et les
  /// clés de synchronisation hors entité) — dérivées des spécifications de
  /// champs générées pour rester synchrones avec le codegen.
  ///
  /// Inclure les clés réservées de `ZSyncMeta` (`updated_at`, `is_deleted`)
  /// est essentiel : les stores écrivent ces clés dans le corps du document
  /// puis passent la map complète à [ZFlashcard.fromMap]. Sans cette
  /// réserve, `is_deleted` (qui n'est pas un champ déclaré) atterrirait dans
  /// [extra] et serait réémis par [toMap] — une fuite d'une préoccupation de
  /// store dans le domaine, cassant l'égalité entre une carte en mémoire et
  /// la même relue.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZFlashcardFieldSpecs) spec.name,
    'source',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = les clés non réservées de [map] (round-trip préservé)
  /// — frontière d'entrée. Délègue à [_sanitizeExtra], la garde partagée.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// La garde partagée de `extra`, appelée par les trois voies : [fromMap],
  /// [copyWith] et [toMap]. Délègue à [zSanitizeExtra] (`zcrud_core`),
  /// l'implémentation unique du dépôt.
  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

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
          zJsonEquals(extra, other.extra);

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
        zJsonHash(extra),
      ]);
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
