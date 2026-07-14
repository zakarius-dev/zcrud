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
/// Réutilise le cœur via `package:zcrud_core/domain.dart` (`ZEntity`,
/// `ZExtensible`, `ZExtension`, `ZSourceRegistry`, `ZFieldSpec`, `ZcrudRegistry`)
/// — même convention d'import que `zcrud_mindmap` ; testé via `flutter test`.
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

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
///
/// Fourni par l'app/le satellite (convention `X.fromJsonSafe`) et injecté dans
/// [ZFlashcard.fromMap] : le cœur ne connaît pas les sous-classes concrètes
/// (AD-4). Toute exception est absorbée en `null` par [ZExtension.guard]
/// (AD-10), le parent survivant toujours.
typedef ZFlashcardExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Flashcard canonique immuable (données + `copyWith` ; invariants au repo).
///
/// **Implémente [ZSessionCandidate]** (ES-1.1, AC6) : `ZFlashcard` est un
/// candidat filtrable par [ZStudySessionSelector] (remonté au noyau) via ses
/// clés neutres `folderId`/`subFolderId`/`tagIds` (déjà présentes) et
/// `typeKey => type.name` (clé de type opaque). Le noyau reste ainsi ignorant de
/// `ZFlashcardType` (AD-17).
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
    // ⚠️ Le « fix » du lint (`this._extra`) est **ILLÉGAL** en Dart : un paramètre
    // NOMMÉ ne peut pas être privé (PRIVATE_OPTIONAL_PARAMETER). Or le slot brut
    // DOIT rester privé — c'est l'ACCESSEUR `extra` qui porte la garde (ES-2.2b).
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

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

  /// Dossier d'appartenance (clé de partitionnement ; port [ZSessionCandidate]).
  @override
  @ZcrudField()
  final String? folderId;

  /// Sous-dossier (hiérarchie 2 niveaux ; port [ZSessionCandidate]).
  @override
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

  /// Étiquettes (défaut `const []` ; filtrage de session ; port
  /// [ZSessionCandidate]).
  @override
  @ZcrudField()
  final List<String> tagIds;

  /// Carte issue d'un partage (lecture seule), défaut `false`.
  @ZcrudField()
  final bool isReadOnly;

  /// Date de création (ISO-8601 ; `null` si éphémère).
  @ZcrudField()
  final DateTime? createdAt;

  /// Date de mise à jour (ISO-8601) — **MIROIR DE COMPATIBILITÉ**, jamais
  /// l'autorité de merge (AD-19).
  ///
  /// L'autorité Last-Write-Wins est **exclusivement** `ZSyncMeta.updatedAt`
  /// (**hors-entité**, `zcrud_core`) : `ZFlashcardRepository` délègue à
  /// `ZSyncableRepository<ZFlashcard>.sync()`, dont le merge passe par
  /// `ZLwwResolver` sur `ZSyncEntry.meta`. Ce champ est **maintenu par
  /// l'adapter** (collision de clé `updated_at`) pour les lectures legacy.
  /// **Ne jamais** l'utiliser pour décider d'un merge, d'un tri de sync ou d'une
  /// résolution de conflit.
  ///
  /// Non déprécié en ES-1.3 (contrairement à `ZStudyFolder.updatedAt`) : sa
  /// surface E9 est consommée par la migration DODLP en cours — dépréciation
  /// formelle à re-statuer (dette **DW-ES13-2**).
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
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Slot `extra` **BRUT tel que reçu par le constructeur** — lu **NULLE PART**
  /// ailleurs que dans l'accesseur [extra] (ni `toMap`, ni `==`, ni `hashCode`).
  ///
  /// Il peut être **POLLUÉ** : le constructeur nominal est `const`, il ne peut
  /// appeler **aucune** fonction dans son initializer, et **AD-10 INTERDIT** d'y
  /// mettre un `assert`. C'est l'**ACCESSEUR** [extra] qui porte la garde
  /// (`zNormalizeExtra`) — **le seul point que TOUTES les voies traversent**.
  final Map<String, dynamic> _extra;

  /// Clé de type **opaque** exposée au port [ZSessionCandidate] (ES-1.1, AC6) :
  /// le `name` camelCase du [type] (ex. `"multipleChoice"`), comparé tel quel au
  /// filtre `types` (`List<String>`) de [ZStudySessionConfig]. Le noyau reste
  /// ignorant de [ZFlashcardType].
  @override
  String get typeKey => type.name;

  /// Sérialise vers la map persistée **complète** (snake_case).
  ///
  /// Réutilise le `toMap()` **généré** (champs scalaires/enum/sous-modèles) puis
  /// ajoute les trois canaux hors-codegen : [extra] (clés inconnues préservées),
  /// [source] (via [sourceRegistry]) et [extension]. Le `registerZFlashcard`
  /// généré appelle ce `toMap()` (il masque l'extension générée).
  Map<String, dynamic> toMap({ZSourceRegistry? sourceRegistry}) {
    final map = <String, dynamic>{
      // 🔴 DW-ES22-3 (ES-2.2b) — MÊME garde nommée qu'en `fromMap`/`copyWith`.
      // `toMap()` est la **frontière de SORTIE** : la seule que TOUTES les voies
      // d'écriture traversent ⇒ promesse INCONDITIONNELLE (constructeur nominal
      // compris — il ne peut RIEN filtrer).
      //
      // ⚠️ **L'ORDRE DU SPREAD RESTE `{...extra, ...généré}`** : le généré écrase
      // l'`extra`, ce qui PROTÈGE les champs du schéma. Ne pas l'inverser. C'est
      // aussi ce qui rendait le défaut INVISIBLE sur cette entité : le champ
      // métier `updatedAt` écrasait la pollution `updated_at` (MESURÉ : `val=null`)
      // — seul `is_deleted`, qu'aucun champ n'écrase, la révélait.
      // 🔴 ES-2.2b (remédiation HIGH-1) — étale l'**ACCESSEUR** (qui NORMALISE),
      // jamais le champ brut `_extra`. Un `_sanitizeExtra(extra)` ICI serait
      // **DÉCORATIF** — MESURÉ (INJ-A/INJ-B) : le retirer laissait le gate VERT
      // sur 8 entités sur 9. La garde vit à l'accesseur ; l'en retirer rend
      // (i.1a)/(i.1b)/(i.1c) ROUGES.
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
        // 🔴 DW-ES22-3 (ES-2.2b) : MÊME FONCTION NOMMÉE qu'en `fromMap` —
        // `copyWith` ne peut plus ROUVRIR le filtre des clés réservées.
        // ⚠️ Surface publique INCHANGÉE (migration DODLP) : même signature, même
        // sémantique de sentinelle — seule la VALEUR écrite est désormais
        // dépouillée de `updated_at`/`is_deleted` (qui n'ont jamais eu le droit
        // d'y être : AD-16).
        extra: identical(extra, _$undefined)
            ? this.extra
            : _sanitizeExtra(extra as Map<String, dynamic>),
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

  /// Clés persistées **réservées** (champs générés + `source` + `extension` +
  /// **clés de sync hors-entité AD-19**) — dérivées de `$ZFlashcardFieldSpecs`
  /// pour rester synchrones avec le codegen.
  ///
  /// `...ZSyncMeta.reservedKeys` (`updated_at`, `is_deleted`) est **essentiel** :
  /// les stores écrivent ces clés **dans le corps** du document puis passent la
  /// map **complète** à [ZFlashcard.fromMap]. Sans cette réserve, `is_deleted`
  /// (qui n'est **pas** un champ déclaré) atterrirait dans [extra] et serait
  /// **réémis** par [toMap] — fuite d'une préoccupation de store dans le domaine
  /// (AD-16), cassant l'`==` entre une carte en mémoire et la même relue.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZFlashcardFieldSpecs) spec.name,
    'source',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés non réservées de [map] (round-trip préservé) —
  /// **frontière d'ENTRÉE**. C'est [_sanitizeExtra], la garde **partagée**.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// 🔴 **LA GARDE PARTAGÉE DE `extra`** (DW-ES22-3, ES-2.2b) — appelée par les
  /// **TROIS** voies : [fromMap], [copyWith] **et** [toMap]. Délègue à
  /// [zSanitizeExtra] (`zcrud_core`, implémentation UNIQUE du repo).
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
