/// Note intelligente à **contenu partageable** et **contenu typé**.
///
/// ## Invariant AD-28 — le contenu est TYPÉ, jamais une `String` ambiguë
///
/// [content] est une `List<Map<String, dynamic>>` (ops Delta neutres), jamais
/// une `String` dont le format (markdown ou Delta JSON) devrait être deviné à
/// la lecture : le type porte le format par construction, aucune heuristique
/// textuelle n'est nécessaire pour interpréter le corps d'une note. La
/// coercition défensive d'un corpus historique (une `String` markdown, un
/// Delta déjà sérialisé, une valeur corrompue) vit dans
/// [normalizeNoteContentOps] : une `String` non-Delta survit VERBATIM, jamais
/// réduite à `[]`.
///
/// Le pont avec `zcrud_markdown` est une **identité, sans conversion** : la
/// valeur neutre attendue par `ZCodec`/`ZMarkdownField` est exactement
/// `List<Map<String, dynamic>>`, donc `note.content` se branche directement
/// sur l'éditeur sans transformation.
///
/// ## Invariant AD-19/AD-16 — pas d'horodatage de synchronisation inline
///
/// `ZSmartNote` ne déclare **ni `updatedAt` ni `isDeleted`** : l'autorité
/// Last-Write-Wins et le soft-delete vivent HORS-ENTITÉ, dans `ZSyncMeta`, qui
/// est écrite APRÈS le corps à chaque écriture — un champ métier logé sous une
/// de ces clés réservées serait écrasé silencieusement. [createdAt] est
/// conservé : sa clé `created_at` est distincte de toute clé réservée. Aucun
/// `edited_at` n'est introduit : aucune source canonique n'expose de
/// « dernière édition » distincte de l'horodatage de synchronisation.
///
/// ## Audio : hors-schéma
///
/// Aucun champ `audioUrl`/`audioPath`/`audioTextHash` sur l'entité : l'audio
/// vit soit dans [extra] (sans code dédié), soit dans le slot typé
/// [extension] (`ZNoteAudio`, injecté via `extensionParser`). Une note sans
/// audio se désérialise sur son défaut — `extension == null`, jamais un throw.
///
/// ## La voie registre ne type pas le slot `extension`
///
/// `ZNoteAudio` est la première `ZExtension` concrète de ce paquet : la
/// désérialisation via `ZcrudRegistry` (qui appelle [ZSmartNote.fromMap] SANS
/// `extensionParser`) ne type donc jamais ce slot. La DONNÉE reste préservée
/// — le payload non typé est porté par [ZOpaqueNoteExtension] et réémis
/// verbatim — mais le TYPE est perdu sur cette voie (`extension is!
/// ZNoteAudio`). Pour obtenir une instance typée, construire l'entité par
/// [ZSmartNote.fromMap] en passant explicitement `extensionParser:
/// ZNoteAudio.fromJsonSafe`.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_note_content.dart';
import 'z_opaque_note_extension.dart';

part 'z_smart_note.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null` (AD-4).
///
/// Fourni par l'app/le satellite (convention `X.fromJsonSafe` — ici
/// `ZNoteAudio.fromJsonSafe`) et injecté dans [ZSmartNote.fromMap] : le domaine
/// ne connaît pas les sous-classes concrètes. Toute exception est absorbée en
/// `null` par [ZExtension.guard] (AD-10).
typedef ZSmartNoteExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Clé persistée du canal **HORS-CODEGEN** `content`.
///
/// Déclarée **une seule fois** (patron `kLearningKey`), consommée par
/// [ZSmartNote.fromMap], [ZSmartNote.toMap] **et** [ZSmartNote._reservedKeys] :
/// **zéro littéral dupliqué**.
///
/// Elle **DOIT** rester le **snake_case du nom de champ** (`content` →
/// `content`) : c'est la **contrainte normative** de la règle **(g1)** du gate —
/// une clé non dérivable serait un canal que la machine ne peut pas garder.
const String kContentKey = 'content';

/// Note intelligente rattachée à un dossier — **contenu partageable** (AD-26).
@ZcrudModel(kind: 'smart_note')
class ZSmartNote extends ZEntity with ZExtensible {
  /// Construit une note (primitif `const`).
  ///
  /// ⛔ **AUCUN `assert` ici, volontairement** : le décodeur **généré**
  /// (`_$ZSmartNoteFromMap`) appelle ce constructeur avec les valeurs **BRUTES**
  /// de la map persistée. Un `assert` y ferait **échouer la désérialisation d'une
  /// donnée corrompue** — **violation frontale d'AD-10**. Les gardes de valeur
  /// vivent **exclusivement aux frontières** [fromMap] / [copyWith], et elles y
  /// sont **la MÊME fonction nommée** ([normalizeNoteContentOps]) — sans quoi
  /// `copyWith` pourrait rouvrir l'invariant que `fromMap` ferme, alors que la
  /// dartdoc promettrait « jamais négative ».
  const ZSmartNote({
    this.id,
    this.folderId = '',
    this.subFolderId,
    this.title = '',
    List<Map<String, dynamic>> content = kEmptyNoteContent,
    this.createdAt,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // Le « fix » du lint (`this._extra`) est **ILLÉGAL** en Dart : un paramètre
    // NOMMÉ ne peut pas être privé (PRIVATE_OPTIONAL_PARAMETER). Or les slots bruts
    // DOIVENT rester privés — ce sont les ACCESSEURS qui portent les gardes (le
    // `extra` normalisant, la vue immuable PROFONDE `content` ).
    // ignore: prefer_initializing_formals
  })  : _content = content,
        // ignore: prefer_initializing_formals
        _extra = extra;

  /// Reconstruit **défensivement** depuis une map persistée (AD-10) — **aucun cas
  /// ne throw**, pas même `ZSmartNote.fromMap(const <String, dynamic>{})`.
  ///
  /// Délègue au `_$ZSmartNoteFromMap` **généré** pour les champs de schéma
  /// (défauts sûrs : `folder_id`/`title` absents ou non-`String` → `''` ;
  /// `sub_folder_id` illisible → `null` ; `created_at` illisible → `null`), **puis
  /// câble les canaux HORS-CODEGEN** :
  /// [content] via [normalizeNoteContentOps] — une `String`
  ///   markdown legacy **survit VERBATIM**, **jamais** `[]` ;
  /// - [extension] via [extensionParser] (repli `null`) ;
  /// - [extra] = clés **non réservées** de la map (round-trip AD-4).
  ///
  /// Corps **NON NU** obligatoire (`ZExtensible`) : une délégation nue à
  /// `_$ZSmartNoteFromMap` laisserait `extra` **VIDE** — le **build la REFUSE**
  /// (`_rejectNakedCodegenDelegation`) et le garde runtime
  /// `_$zRequireExtraPreserved` émis dans le `.g.dart` **lèverait à
  /// l'enregistrement**, y compris **en release**.
  factory ZSmartNote.fromMap(
    Map<String, dynamic> map, {
    ZSmartNoteExtensionParser? extensionParser,
  }) {
    final base = _$ZSmartNoteFromMap(map);
    return ZSmartNote(
      id: base.id,
      folderId: base.folderId,
      subFolderId: base.subFolderId,
      title: base.title,
      // CANAL HORS-CODEGEN — la MÊME garde qu'en `copyWith`.
      content: normalizeNoteContentOps(map[kContentKey]),
      createdAt: base.createdAt,
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité opaque (`null` pour l'éphémère — **jamais attribuée par l'entité** ;
  /// la matérialisation est au repository). Invariant AD-14.
  @override
  @ZcrudId()
  final String? id;

  /// Dossier d'appartenance — **clé NEUTRE `String`** (défaut `''`).
  ///
  /// **Aucun symbole de `zcrud_study_kernel` n'est importé** (leçon **L2**
  /// « dépendance DÉCLARÉE, aucun import ») — exactement comme
  /// `ZFlashcard.folderId` et `zcrud_mindmap`.
  @ZcrudField()
  final String folderId;

  /// Sous-dossier optionnel (`null` si absent).
  @ZcrudField()
  final String? subFolderId;

  /// Titre de la note (défaut `''`).
  @ZcrudField(label: 'Titre')
  final String title;

  /// **Corps de la note — ops Delta NEUTRES** (`List<Map<String, dynamic>>`),
  /// **CANAL HORS-CODEGEN**, défaut `[]`.
  ///
  /// **Pourquoi hors-codegen** : le générateur ne supporte **aucun type `Map`**
  /// (`_classify` : `List<T>` récurse sur `T`, et `Map` n'a **aucune branche`) ⇒
  /// annoter ce champ `@ZcrudField` rendrait le **build ROUGE**. Il est donc
  /// décodé et réémis **À LA MAIN** (patron `ZFlashcard.source` /
  /// `ZDocumentReadingState.learning`), et sa clé [kContentKey] est
  /// **RÉSERVÉE** — sinon elle atterrirait dans [extra] **et** serait réémise
  /// **en double** par [toMap], cassant l'`==` entre une note en mémoire et la
  /// même relue du store.
  ///
  /// **Conséquence assumée** : un canal hors-codegen ne produit **aucun
  /// `ZFieldSpec`** ⇒ `content` **n'apparaîtra PAS** dans un formulaire
  /// `DynamicEdition` **généré**. **Ce n'est pas un oubli** — c'est déjà le cas de
  /// `ZFlashcard.source` et `ZDocumentReadingState.learning`. L'éditeur de note
  /// (`ZSmartNoteEditor`) ajoute son `ZMarkdownField` **explicitement**, câblé
  /// sur `note.content` — **sans conversion** (la valeur neutre de `ZCodec`
  /// **EST** ce type).
  ///
  /// **NON MODIFIABLE en PROFONDEUR INCONDITIONNELLEMENT** :
  /// l'accesseur rend une vue `unmodifiable` de la liste, de **chaque op** ET de
  /// ses valeurs imbriquées — muter l'une d'elles lève `UnsupportedError`, **même**
  /// sur une instance née du ctor `const` invoqué non-`const`. Le slot STOCKÉ
  /// [_content] reste BRUT (le ctor `const` l'exige).
  List<Map<String, dynamic>> get content => zUnmodifiableJsonMapList(_content);

  /// Slot **BRUT tel que reçu par le constructeur** — lu **NULLE PART** ailleurs
  /// que dans l'accesseur [content] (le ctor `const` ne peut pas le filtrer).
  final List<Map<String, dynamic>> _content;

  /// Date de création — clé `created_at`, **DISTINCTE** de toute clé réservée.
  ///
  /// ⛔ Il n'y a **volontairement AUCUN** `updatedAt` ici : la clé LWW est
  /// **hors-entité** (`ZSyncMeta.updatedAt`) — cf. la dartdoc de bibliothèque
  /// (AD-19). Le porter — comme lex le fait — le ferait **écraser
  /// silencieusement** par le store à chaque `put`.
  @ZcrudField()
  final DateTime? createdAt;

  /// Slot type additif **versionné** (AD-4 pt.1) — hors-codegen.
  ///
  /// Trois états possibles (**et un seul rend `null`**) :
  /// - **`null`** ⇒ la clé `extension` est **absente** du store, ou son payload
  ///   n'est **pas une `Map`** (rien de structuré à préserver) ;
  /// - **`ZNoteAudio`** ⇒ un `extensionParser` a été **injecté** dans
  ///   [fromMap] **et** a su typer le payload ;
  /// - **[ZOpaqueNoteExtension]** ⇒ le payload est une `Map` que **rien n'a su
  /// typer** : aucun parser injecté (**voie du REGISTRE**) ou
  ///   **version future/non gérée** . Le payload est **PORTÉ VERBATIM**
  ///   et **RÉÉMIS À L'IDENTIQUE** par [toMap] — il n'est **PLUS DÉTRUIT**.
  ///
  /// ## ⛔ — CE QUE LE STORE NE SAIT TOUJOURS PAS FAIRE
  ///
  /// `ZcrudRegistry`/`FirebaseZRepositoryImpl.fromRegistry` appellent
  /// `ZSmartNote.fromMap(map)` **TOUT COURT** : **aucun slot d'injection** de
  /// parser n'existe (le correctif reste dans `zcrud_core`, hors périmètre
  /// ici). ⇒ Sur cette voie, `extension` est **TOUJOURS** une
  /// [ZOpaqueNoteExtension], **jamais** un `ZNoteAudio` : **la donnée survit, le
  /// TYPE ne revient pas** — l'app **ne peut pas s'en servir**.
  ///
  /// ⇒ Pour **utiliser** l'audio, câbler l'entité par le **constructeur nominal**
  /// avec `extensionParser: ZNoteAudio.fromJsonSafe`. La perte fonctionnelle est
  /// **épinglée en machine** (`z_smart_note_test.dart`) : **`ZNoteAudio`
  /// FALSIFIE la clause d'échappement** (*« l'entité n'utilise pas
  /// le slot `extension` »*) qui, sinon, garde la voie registre utilisable.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (AD-4 pt.2), défaut `const {}` (jamais `null`).
  ///
  /// **Porte l'audio top-level legacy** (`audio_url` / `audio_path` /
  /// `audio_text_hash`) et les champs d'un consommateur legacy sans équivalent
  /// canonique (`audioText`, `subjectId`, `creatorId`) — **jamais** le schéma
  /// partagé.
  /// Hors-codegen.
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

  /// Sérialise vers la map persistée **complète** (snake_case), **zéro-perte**.
  ///
  /// Réutilise le `toMap()` **généré** (champs du schéma) puis superpose les
  /// **trois** canaux hors-codegen : [extra], [content] (**TOUJOURS** émis, même
  /// vide — round-trip **idempotent**, patron `learning`) et [extension].
  ///
  /// ⛔ **Ne réémet NI `updated_at` NI `is_deleted`** — **et cette promesse est
  /// désormais TENUE SUR TOUTES LES VOIES** : ces clés appartiennent au store
  /// (`ZSyncMeta`), pas au domaine (AD-16/AD-19).
  ///
  /// **Remédiation apportée** : la v1 promettait cela
  /// **SANS CONDITION** dans cette dartdoc… et ne le tenait que sur la voie
  /// [fromMap]. `copyWith(extra:)` et le constructeur **ne traversaient pas** le
  /// filtre des clés réservées ⇒ **MESURÉ** :
  /// `note.copyWith(extra: {'updated_at': '1999-01-01', 'is_deleted': true}).toMap()`
  /// **réémettait les deux clés**. C'est **exactement** la forme du finding **H2**
  /// (*« `copyWith` contournait une garde que la dartdoc PROMETTAIT »*)
  /// rejouée sur l'**autre** garde du même `fromMap`.
  /// ⇒ Le dépouillement est une **fonction nommée UNIQUE** ([_sanitizeExtra]),
  /// appelée par **[fromMap] ET [copyWith] ET [toMap]** — **aucune** voie
  /// d'écriture ne peut la contourner (le constructeur `const` ne peut pas
  /// l'appeler — AD-10 interdit d'y mettre un `assert` — donc [toMap], **frontière
  /// de SORTIE**, la rejoue : c'est ce qui rend la promesse **inconditionnelle**).
  ///
  /// **Impact réel du défaut** : un `put` écrivait un `updated_at` **métier** dans
  /// le corps ; le store réécrit sa méta **APRÈS** le corps (AD-19) ⇒ écrasement
  /// silencieux, ou corruption de l'autorité LWW selon l'ordre — c'est ce
  /// piège que ce `toMap()` d'instance ferme.
  ///
  /// **Indispensable** : le `toMap()` **GÉNÉRÉ** n'étale **ni `extra` ni le
  /// canal** — sans ce `toMap()` d'**instance**, ce que [fromMap] a préservé ne
  /// serait **jamais réémis** (jambe « sortie » de la garde, observée par le
  /// garde runtime émis dans le `.g.dart`).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // la MÊME garde nommée qu'en `fromMap`/`copyWith`. Une note
      // construite par le constructeur nominal (qui, lui, ne peut RIEN filtrer :
      // il est `const`) ne peut plus faire mentir la promesse ci-dessus.
      // (remédiation) — étale l'**ACCESSEUR** (qui NORMALISE)
      // jamais le champ brut `_extra`. Un `_sanitizeExtra(extra)` ICI serait
      // **DÉCORATIF** — le retirer laissait le gate VERT
      // sur 8 entités sur 9. La garde vit à l'accesseur ; l'en retirer rend
      // (i.1a)/(i.1b)/(i.1c) ROUGES.
      ...extra,
      ...ZSmartNoteZcrud(this).toMap(),
      kContentKey: content,
    };
    if (extension != null) {
      // Payload TYPÉ (`ZNoteAudio`) ou payload OPAQUE non décodé
      // (`ZOpaqueNoteExtension` ⇒ réémission VERBATIM) : dans les deux cas, le
      // slot SURVIT au round-trip .
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie **à sentinelle** (un argument omis préserve la valeur, `null` explicite
  /// la remet à `null`) — couvre **TOUS** les champs, y compris [content],
  /// [extension] et [extra], que le `copyWith` **GÉNÉRÉ** remettrait à leurs
  /// **défauts** (perte silencieuse). Masque le `copyWith` de l'extension.
  ///
  /// **[content] est NORMALISÉ — par la MÊME fonction qu'en [fromMap]**
  /// ([normalizeNoteContentOps]) : leçon **H2**. Un invariant de valeur a
  /// **DEUX** frontières — la **désérialisation** (une valeur corrompue qui ENTRE)
  /// **et** la **mutation applicative** (une valeur hors-domaine qu'on ÉCRIT). Ne
  /// fermer que la première laisse la garde **ROUVRABLE** :
  /// `note.copyWith(content: [{'retain': 1}])` persisterait une op **invalide**,
  /// que la relecture **modifierait silencieusement** ⇒ round-trip **non
  /// idempotent**, `==` cassée entre la note en mémoire et la même relue du store.
  ZSmartNote copyWith({
    Object? id = _$undefined,
    Object? folderId = _$undefined,
    Object? subFolderId = _$undefined,
    Object? title = _$undefined,
    Object? content = _$undefined,
    Object? createdAt = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) {
    return ZSmartNote(
      id: identical(id, _$undefined) ? this.id : id as String?,
      folderId:
          identical(folderId, _$undefined) ? this.folderId : folderId as String,
      subFolderId: identical(subFolderId, _$undefined)
          ? this.subFolderId
          : subFolderId as String?,
      title: identical(title, _$undefined) ? this.title : title as String,
      // H2 : la garde est la MÊME FONCTION NOMMÉE qu'en `fromMap` — aucune voie
      // d'écriture ne la contourne, et deux implémentations jumelles ne peuvent
      // pas diverger.
      content: identical(content, _$undefined)
          ? this.content
          : normalizeNoteContentOps(content),
      createdAt: identical(createdAt, _$undefined)
          ? this.createdAt
          : createdAt as DateTime?,
      extension: identical(extension, _$undefined)
          ? this.extension
          : extension as ZExtension?,
      // la garde de `extra` est la MÊME FONCTION NOMMÉE qu'en
      // `fromMap` — `copyWith` ne peut plus ROUVRIR le filtre des clés réservées
      // (leçon H2, appliquée à `content` mais OUBLIÉE sur `extra` en v1).
      extra: identical(extra, _$undefined)
          ? this.extra
          : _sanitizeExtra(extra as Map<String, dynamic>),
    );
  }

  /// Décode l'extension **sans JAMAIS détruire son payload** (AD-4 pt.1, AD-10).
  ///
  /// 1. payload non-`Map` (`42`, `'texte'`, `[]`) ⇒ `null` — **rien de structuré à
  ///    préserver** ;
  /// 2. [parser] injecté **et** capable de typer le payload ⇒ l'extension
  ///    **TYPÉE** (`ZNoteAudio`) ;
  /// 3. **sinon** — aucun parser (**voie du REGISTRE**) **ou** parser
  ///    rendant `null` (**version future/non gérée**) ⇒
  ///    [ZOpaqueNoteExtension] : le payload est **PORTÉ VERBATIM** et
  ///    **RÉÉMIS À L'IDENTIQUE** par [toMap].
  ///
  /// **Avant cette remédiation, les cas 3 rendaient `null` ⇒ [toMap] n'émettait
  /// PAS la clé ⇒ le slot était EFFACÉ DU STORE au premier `put`, irréversiblement**
  /// (MESURÉ — MAJEUR-1/MAJEUR-2). `'extension'` étant une clé **réservée**, le
  /// payload ne tombait **pas non plus** dans [extra] : il était **purement perdu**.
  static ZExtension? _decodeExtension(
    Object? raw,
    ZSmartNoteExtensionParser? parser,
  ) {
    final map = _asStringMap(raw);
    if (map == null) return null;
    final typed = parser == null
        ? null
        : ZExtension.guard<ZExtension?>(() => parser(map));
    // PRÉSERVATION : ce qu'on ne sait pas typer, on ne le DÉTRUIT PAS.
    return typed ?? ZOpaqueNoteExtension.of(map);
  }

  /// Clés persistées **RÉSERVÉES** (champs générés + `extension` + **[kContentKey]**
  /// + **clés de sync `ZSyncMeta`**) — dérivées de `$ZSmartNoteFieldSpecs` pour
  /// rester synchrones avec le codegen.
  ///
  /// **`...ZSyncMeta.reservedKeys` est ESSENTIEL** : cette
  /// entité est persistée **top-level** et le store écrit `updated_at`/`is_deleted`
  /// **dans le corps** du document avant de passer la map **complète** à [fromMap].
  /// Sans ce spread, ces clés — qui appartiennent au **store** — atterriraient dans
  /// [extra] (AD-4 violé) et seraient **réémises** par [toMap] (AD-16 violé).
  /// L'oubli est facile à manquer sous une suite de tests par ailleurs verte :
  /// il est ici prouvé **COMPORTEMENTALEMENT** (groupe de tests « AD-19 » +
  /// volet (A) du gate `reserved-keys`), jamais par la seule lecture.
  ///
  /// **[kContentKey] est ESSENTIEL** (règle **(g1)**) : le canal hors-codegen
  /// étant réémis **à la main** par [toMap], sa clé DOIT être réservée — sinon elle
  /// atterrirait **aussi** dans [extra] et serait émise **deux fois** (une par
  /// `...extra`, une par le câblage manuel), cassant l'idempotence du round-trip.
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZSmartNoteFieldSpecs) spec.name,
    'extension',
    kContentKey,
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés **non réservées** de [map] (round-trip préservé) —
  /// **frontière d'ENTRÉE** (patron prescrit par `zcrud_generator`).
  ///
  /// C'est **[_sanitizeExtra]**, la garde **partagée** : `fromMap`,
  /// `copyWith` et `toMap` appellent **la même** fonction nommée.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// **LA GARDE PARTAGÉE DE `extra`** — dépouille **toute** clé
  /// **RÉSERVÉE** (champs du schéma, `extension`, [kContentKey], **et les clés de
  /// sync `ZSyncMeta`**) et rend une `Map` **non modifiable**.
  ///
  /// Un invariant de valeur a **DEUX** frontières — la **désérialisation** (une
  /// valeur corrompue qui ENTRE) **et** la **mutation applicative** (une valeur
  /// hors-domaine qu'on ÉCRIT). La v1 ne fermait que la première **pour `extra`**
  /// (elle avait pourtant fermé les deux **pour `content`**) : `copyWith(extra:)`
  /// **rouvrait** le filtre, et [toMap] réémettait alors `updated_at`/`is_deleted`
  /// — **en contradiction directe avec sa propre dartdoc**. Une **fonction nommée
  /// unique**, appelée par **les trois** voies, rend le contournement
  /// **structurellement impossible** ; deux implémentations jumelles ne peuvent pas
  /// diverger.
  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      Map<String, dynamic>.unmodifiable(<String, dynamic>{
        for (final e in raw.entries)
          if (!_reservedKeys.contains(e.key)) e.key: e.value,
      });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSmartNote &&
          id == other.id &&
          folderId == other.folderId &&
          subFolderId == other.subFolderId &&
          title == other.title &&
          // Égalité PROFONDE : `==` de `List`/`Map` est une égalité d'IDENTITÉ en
          // Dart — sans elle, une note en mémoire et la même relue du store
          // seraient DIFFÉRENTES.
          noteContentEquals(content, other.content) &&
          createdAt == other.createdAt &&
          extension == other.extension &&
          // 🟡 MEDIUM-1 : `extra` porte du JSON ARBITRAIRE (donc IMBRIQUÉ) —
          // l'argument écrit pour `content` s'y applique MOT POUR MOT. Une égalité
          // SUPERFICIELLE cassait `fromMap(m) == fromMap(m)` dès qu'une clé legacy
          // portait une `Map`/`List` (MESURÉ).
          noteJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        folderId,
        subFolderId,
        title,
        noteContentHash(content),
        createdAt,
        extension,
        noteJsonHash(extra),
      ]);
}

/// Coerce défensive vers `Map<String, dynamic>` (repli `null`).
///
/// 🔵 **L3** : le `try/catch` qui enveloppait la coercition des clés était **MORT**
/// (l'interpolation `'${e.key}'` d'un `Object?` ne peut pas lever) — supprimé (R6 :
/// aucun filet décoratif).
Map<String, dynamic>? _asStringMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    return <String, dynamic>{for (final e in v.entries) '${e.key}': e.value};
  }
  return null;
}
