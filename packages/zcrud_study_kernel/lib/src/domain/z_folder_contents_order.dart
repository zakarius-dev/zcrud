/// Ordre de contenu **PERSONNEL** d'un dossier d'étude `ZFolderContentsOrder`
/// (ES-2.4, FR-S7).
///
/// origine: lex_core (module « Étude ») — `entities/education/folder_contents_order.dart`
/// (`{folderId, orders: Map<sectionKey, List<id>>}`,
/// `@JsonSerializable(fieldRename: snake)`).
///
/// ## 🔴 AD-26 — ÉTAT PERSONNEL, JAMAIS COLOCALISÉ AVEC LE CONTENU PARTAGEABLE
///
/// L'ordre choisi par l'utilisateur (la liste ordonnée des ids d'items **par
/// section**) est **strictement personnel** : il ne vit **jamais** dans le
/// sous-arbre **partageable** du dossier ([ZStudyFolder]) — exactement comme
/// `ZRepetitionInfo` (SRS) ne vit jamais dans la carte et `ZDocumentReadingState`
/// (lecture) jamais dans le document. **Partager ou dupliquer un dossier n'emporte
/// donc JAMAIS l'ordre personnel d'autrui.** La non-colocation est prouvée **par
/// machine** (aucune clé d'ordre dans `$ZStudyFolderFieldSpecs`, l'entité n'est
/// jamais imbriquée dans [ZStudyFolder]). La **résolution de collection** (le
/// « où », p. ex. `study_content_orders/{folderId}`) reste du ressort de
/// `ZFirestorePathResolver` — **ES-3.2, hors périmètre de cette story**.
///
/// **Confrontation à la source lex (D1, R-G)** : lex loge DÉJÀ cet état **hors**
/// du sous-arbre partagé (`users/{uid}/study_content_orders/{folderId}`, doc id =
/// `folderId`) et **ne déclare NI `updatedAt` NI `isDeleted` inline** — contrairement
/// au piège rencontré sur `ZDocumentReadingState` (où lex logeait `updatedAt` dans
/// le corps métier). Le port est ici **propre** : aucun piège AD-26/AD-19 à rejeter,
/// seulement l'adaptation au patron zcrud (canal hors-codegen + `ZExtensible`).
///
/// ## 🔴 D8 — PAS un `ZEntity` : la clé d'identité est [folderId]
///
/// Jointure **1↔1** avec le dossier (patron `ZDocumentReadingState` clé par
/// `docId`, `ZRepetitionInfo` clé par `flashcardId`) : **aucun `id` propre**,
/// aucune réconciliation d'identifiant. La clé d'identité est [folderId].
///
/// ## 🔴 D3 — [sectionOrders] est un CANAL **HORS-CODEGEN** (patron `learning`)
///
/// Le champ payload est un `Map<String, List<String>>` (`sectionKey → ordre
/// d'ids`). Le générateur `zcrud` **ne supporte AUCUN type `Map`** : `_classify`
/// (`zcrud_model_generator.dart`) accepte `String`/`int`/`double`/`num`/`bool`/
/// `DateTime`/enum/sous-modèle `@ZcrudModel` et les `List<` de ces types — **aucune
/// branche `isDartCoreMap`**. C'est le **`Map` extérieur** qui interdit le codegen
/// (les `List<String>` intérieures, elles, sont codegen-ables — cf.
/// `ZStudySessionConfig.tagIds`) : le canal ENTIER est donc décodé/réémis **à la
/// main**, et sa clé [kSectionOrdersKey] est **RÉSERVÉE** — sans quoi elle
/// atterrirait **aussi** dans [extra] et serait émise **DEUX FOIS** (une par
/// `...extra`, une par le câblage manuel), cassant l'idempotence du round-trip et
/// l'`==` mémoire-vs-store.
///
/// Le **SEUL** `@ZcrudField` codegen-able est [folderId] (`String`).
///
/// ## 🔴 D3-bis — décodage défensif à DEUX niveaux + immuabilité PROFONDE (M3)
///
/// Le canal a deux niveaux de corruption (le `Map` extérieur ET chaque `List`
/// intérieure), chacun avec sa garde (AD-10, jamais de throw) :
/// - `section_orders` absente / non-`Map` (`42`, `"x"`, une liste) ⇒ `{}` ;
/// - valeur de section **non-`List`** (`{"a": 7}`) ⇒ section **ignorée** ;
/// - élément **non-`String`** (`["a", 3, null]`) ⇒ élément **filtré**, ordre
///   relatif préservé (même tolérance que `tag_ids`) ;
/// - clés de section et ids **verbatim** (opaques, `''` toléré comme clé opaque).
///
/// **Immuabilité M3** : la map exposée **ET ses listes internes** sont rendues
/// **NON MODIFIABLES en profondeur** aux frontières qui la construisent
/// ([fromMap], [copyWith], décodage). Une mutation en place contournerait
/// l'invariant, changerait le [hashCode] et **perdrait l'instance dans son propre
/// `Set`** (patron `ZDocumentLearningInfo.qualityByPage`).
///
/// **PAS de dédoublonnage au stockage** : l'ordre est préservé **verbatim**
/// (round-trip byte-stable) ; les doublons éventuels sont neutralisés **à
/// l'application** par [applyOrder] (1re occurrence gagne). Ne pas « nettoyer » au
/// décodage — ce serait une perte muette (R6).
///
/// ## 🔴 D4 — [applyTo] DÉLÈGUE à `applyOrder<T>` (ES-1.2) — aucune primitive neuve
///
/// L'intégrité ordre↔contenu est portée **gratuitement** par [applyOrder] (déjà
/// TOTAL et défensif : id d'ordre sans item **ignoré**, item hors-ordre en
/// position **déterministe**, doublon d'ordre → 1re occurrence). Cette story ne
/// livre **AUCUNE primitive d'intégrité référentielle** (contraste avec
/// `orphanTagIds` d'ES-2.3) : l'AC de l'epic ES-2.4 n'en mentionne aucune, et la
/// réconciliation/purge (retirer d'un ordre les ids de contenu supprimés) est du
/// ressort **repository/UI** (ES-5.2 / ES-8, hors périmètre).
///
/// ## 🔴 D5 — Égalité : ordre-SENSIBLE dans une liste, ordre-INSENSIBLE entre sections
///
/// **L'ORDRE EST LE PAYLOAD** : deux instances au même [folderId] dont **une
/// section a sa liste inversée** sont **INÉGALES** (comparaison **positionnelle**
/// des listes, hash de liste **ordre-sensible** `Object.hashAll`). Mais l'ordre des
/// **clés** de la `Map` n'a aucun sens : deux instances aux mêmes sections insérées
/// dans un ordre de clés différent sont **ÉGALES** (lookup ensembliste, hash
/// extérieur **COMMUTATIF** — somme sur les sections). C'est le `DeepCollectionEquality`
/// de lex, réexprimé : hash intérieur ordre-sensible, hash extérieur commutatif.
///
/// ## 🔴 AD-19 — zéro clé de sync (R-C)
///
/// [_reservedKeys] ⊇ `ZSyncMeta.reservedKeys` (`updated_at`, `is_deleted`) : ces
/// clés appartiennent au **store** (AD-16), l'entité étant persistée top-level, le
/// store les écrit **dans le corps** avant de passer la map complète à [fromMap].
/// Sans ce spread, elles atterriraient dans [extra] et seraient réémises par
/// [toMap]. `$ZFolderContentsOrderFieldSpecs ∩ ZSyncMeta.reservedKeys == {}`.
///
/// Pur Dart — aucune dépendance Flutter/Firebase (AD-1/AD-17, ids `String` neutres).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'apply_order.dart';

part 'z_folder_contents_order.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null` (AD-4).
///
/// Fourni par l'app/le satellite (convention `X.fromJsonSafe`) et injecté dans
/// [ZFolderContentsOrder.fromMap] : le cœur ne connaît pas les sous-classes
/// concrètes. Toute exception est absorbée en `null` par [ZExtension.guard].
typedef ZFolderContentsOrderExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Clé persistée du **canal hors-codegen** [ZFolderContentsOrder.sectionOrders]
/// (D3).
///
/// Déclarée **une seule fois** (top-level `const`, résolue par le gate
/// `reserved-keys`), consommée par [ZFolderContentsOrder.fromMap],
/// [ZFolderContentsOrder.toMap] **et** [ZFolderContentsOrder._reservedKeys] :
/// aucun littéral dupliqué (patron `kLearningKey`).
const String kSectionOrdersKey = 'section_orders';

/// Ordre de contenu personnel d'un dossier — clé par [folderId] (**pas** un
/// `ZEntity`, D8).
@ZcrudModel(kind: 'folder_contents_order')
class ZFolderContentsOrder with ZExtensible {
  /// Construit un ordre de contenu (primitif `const`).
  ///
  /// ⚠️ **Ne filtre / ne garde RIEN** (`const` : ne peut appeler aucune fonction,
  /// AD-10 y interdit l'`assert`). L'immuabilité PROFONDE de [sectionOrders] est
  /// portée par les frontières qui CONSTRUISENT la map ([fromMap]/[copyWith]), et
  /// la garde de [extra] par l'ACCESSEUR — patron `ZDocumentReadingState` /
  /// `ZDocumentLearningInfo`.
  const ZFolderContentsOrder({
    this.folderId = '',
    Map<String, List<String>> sectionOrders = const <String, List<String>>{},
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ⚠️ Le « fix » du lint (`this._extra`) est **ILLÉGAL** en Dart : un paramètre
    // NOMMÉ ne peut pas être privé (PRIVATE_OPTIONAL_PARAMETER). Or les slots bruts
    // DOIVENT rester privés — ce sont les ACCESSEURS qui portent les gardes (le
    // `extra` normalisant ES-2.2b, la vue immuable PROFONDE `sectionOrders`
    // DW-ES24-1).
    // ignore: prefer_initializing_formals
  })  : _sectionOrders = sectionOrders,
        // ignore: prefer_initializing_formals
        _extra = extra;

  /// Reconstruit **défensivement** depuis une map persistée (AD-10) — **ne throw
  /// JAMAIS**, pas même `ZFolderContentsOrder.fromMap(const {})`.
  ///
  /// Recopie le champ codegen ([folderId], via `_$ZFolderContentsOrderFromMap` —
  /// `folder_id` absent/non-`String` → `''`) PUIS câble les canaux **hors-codegen** :
  /// `section_orders` (**D3**, décodage 2 niveaux + immuabilité profonde M3 via
  /// [_decodeSectionOrders]), [extension] (repli `null`) et [extra] (clés **non
  /// réservées**).
  ///
  /// ⛔ **Ne délègue JAMAIS nuement** à `_$ZFolderContentsOrderFromMap` (l'entité
  /// est `ZExtensible` : le build passerait ROUGE via la garde runtime
  /// `_$zRequireExtraPreserved`) — elle **peuple `extra: _extraFrom(map)`** ET le
  /// canal `section_orders`.
  factory ZFolderContentsOrder.fromMap(
    Map<String, dynamic> map, {
    ZFolderContentsOrderExtensionParser? extensionParser,
  }) {
    final base = _$ZFolderContentsOrderFromMap(map);
    return ZFolderContentsOrder(
      folderId: base.folderId,
      // 🔴 CANAL HORS-CODEGEN (D3) — décodage défensif à 2 niveaux + M3.
      sectionOrders: _decodeSectionOrders(map[kSectionOrdersKey]),
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité : le dossier dont c'est l'ordre de contenu (jointure **1↔1**).
  /// Défaut `''`. **Pas d'`id` propre** (D8).
  @ZcrudField()
  final String folderId;

  /// Ordre personnel par section — **CANAL HORS-CODEGEN** (D3, patron
  /// `ZDocumentReadingState.learning`) : sa clé [kSectionOrdersKey] est
  /// **réservée**, il est décodé/réémis **à la main**. `sectionKey → [id, id, …]`.
  ///
  /// 🔴 **NON MODIFIABLE en PROFONDEUR INCONDITIONNELLEMENT** (DW-ES24-1) :
  /// l'accesseur rend une vue `unmodifiable` de la map **ET de chaque liste
  /// interne** — muter l'une ou l'autre lève `UnsupportedError`, **même** sur une
  /// instance née du ctor `const` invoqué non-`const`. Sans quoi une mutation en
  /// place changerait le [hashCode] et perdrait l'instance dans son propre `Set`.
  /// Une section absente ⇒ **aucun ordre** (items rendus dans leur ordre d'entrée
  /// par [applyTo]).
  Map<String, List<String>> get sectionOrders =>
      zUnmodifiableMapOfLists(_sectionOrders);

  /// Slot **BRUT tel que reçu par le constructeur** — lu **NULLE PART** ailleurs
  /// que dans l'accesseur [sectionOrders] (le ctor `const` ne peut pas le filtrer).
  final Map<String, List<String>> _sectionOrders;

  /// Slot type additif **versionné** (AD-4 pt.1), `null` si absent. Hors-codegen.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (AD-4 pt.2), défaut `const {}` (jamais `null`).
  /// Hors-codegen.
  ///
  /// 🔴 **GARDE (ES-2.2b)** : l'accesseur **NORMALISE** ([zNormalizeExtra]) — il
  /// ne rend **JAMAIS** une clé réservée (dont [kSectionOrdersKey] et les clés de
  /// sync), **quelle que soit la voie d'écriture** (y compris le ctor `const`, seule
  /// voie incapable de filtrer). C'est **le seul point que TOUTES les voies
  /// traversent** ⇒ promesse **INCONDITIONNELLE**, sans `assert` ni `throw` (AD-10).
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Slot `extra` **BRUT tel que reçu par le constructeur** — lu **NULLE PART**
  /// ailleurs que dans l'accesseur [extra] (ni `toMap`, ni `==`, ni `hashCode`).
  ///
  /// Il peut être **POLLUÉ** : le constructeur nominal est `const`, il ne peut
  /// appeler **aucune** fonction, et **AD-10 INTERDIT** l'`assert`. C'est
  /// l'ACCESSEUR qui porte la garde.
  final Map<String, dynamic> _extra;

  /// Sérialise vers la map persistée **complète** (snake_case), zéro-perte.
  ///
  /// Réutilise le `toMap()` **généré** ([folderId]) puis superpose les canaux
  /// hors-codegen : [extra] (l'ACCESSEUR normalisant), `section_orders`
  /// (**toujours** émis, même `{}` — round-trip **idempotent**) et [extension].
  ///
  /// ⛔ **Ne réémet NI `updated_at` NI `is_deleted`** : ces clés appartiennent au
  /// store (`ZSyncMeta`), pas au domaine (AD-16/AD-19) — garanti par construction
  /// ([_reservedKeys] ⊇ `ZSyncMeta.reservedKeys` ⇒ elles ne peuvent entrer dans
  /// [extra], donc plus en ressortir).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // 🔴 ES-2.2b — étale l'**ACCESSEUR** (qui NORMALISE), jamais le champ brut
      // `_extra` : c'est ce qui rend la promesse INCONDITIONNELLE, y compris pour
      // une instance née du constructeur nominal (`const` : il ne filtre RIEN).
      ...extra,
      ...ZFolderContentsOrderZcrud(this).toMap(),
      // 🔴 CANAL HORS-CODEGEN (D3) — TOUJOURS émis (même `{}`) ⇒ idempotence.
      kSectionOrdersKey: _encodeSectionOrders(sectionOrders),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie **à sentinelle** — couvre **TOUS** les champs, y compris
  /// [sectionOrders], [extension] et [extra] (que le `copyWith` **généré** ignore
  /// ou remettrait à leurs défauts : perte silencieuse).
  ///
  /// [sectionOrders] fourni est **regardé** (M3 : filtré en profondeur et rendu
  /// NON MODIFIABLE) — une mutation applicative ne rouvre pas l'invariant que
  /// [fromMap] ferme.
  ZFolderContentsOrder copyWith({
    Object? folderId = _$undefined,
    Object? sectionOrders = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) =>
      ZFolderContentsOrder(
        folderId:
            identical(folderId, _$undefined) ? this.folderId : folderId as String,
        // M3 : la map fournie est rendue NON MODIFIABLE en profondeur (la garde
        // vit AUSSI ici — une mutation applicative ne rouvre pas l'invariant).
        sectionOrders: identical(sectionOrders, _$undefined)
            ? this.sectionOrders
            : _guardSectionOrders(sectionOrders as Map<String, List<String>>),
        extension: identical(extension, _$undefined)
            ? this.extension
            : extension as ZExtension?,
        // 🔴 ES-2.2b : MÊME FONCTION NOMMÉE qu'en `fromMap` — `copyWith` ne peut
        // plus ROUVRIR le filtre des clés réservées.
        extra: identical(extra, _$undefined)
            ? this.extra
            : _sanitizeExtra(extra as Map<String, dynamic>),
      );

  /// Ordre mémorisé pour [sectionKey] (liste **vide** si aucun) — accès direct au
  /// canal, sans réordonner.
  List<String> orderFor(String sectionKey) =>
      sectionOrders[sectionKey] ?? const <String>[];

  /// Réordonne [items] selon l'ordre personnel de [sectionKey] en **DÉLÉGUANT** à
  /// [applyOrder] (ES-1.2 — jamais de tri réinventé, D4/R6).
  ///
  /// Fonction **pure** et **totale** : ordre partiel/permuté appliqué de façon
  /// **stable**, items absents de l'ordre placés en position **déterministe**
  /// ([unordered]), id d'ordre sans item **ignoré**, doublon d'ordre → 1re
  /// occurrence. Section absente ⇒ ordre d'entrée de [items] préservé.
  List<T> applyTo<T>(
    String sectionKey,
    Iterable<T> items, {
    required String Function(T item) idOf,
    ZUnorderedPlacement unordered = ZUnorderedPlacement.end,
  }) =>
      applyOrder(
        items,
        sectionOrders[sectionKey] ?? const <String>[],
        idOf: idOf,
        unordered: unordered,
      );

  // ---------------------------------------------------------------------------
  // Canal hors-codegen `section_orders` — décodage / encodage / garde M3
  // ---------------------------------------------------------------------------

  /// Décode **défensivement** le canal à **DEUX niveaux** (AD-10, M3) — jamais de
  /// throw. Rend une map **profondément NON MODIFIABLE**.
  static Map<String, List<String>> _decodeSectionOrders(Object? raw) {
    // Niveau 1 : le `Map` extérieur (`42`, `"x"`, une liste, absent) ⇒ `{}`.
    if (raw is! Map) return const <String, List<String>>{};
    final out = <String, List<String>>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      // Niveau 2a : valeur de section non-`List` ⇒ section IGNORÉE.
      if (value is! List) continue;
      final ids = <String>[];
      for (final element in value) {
        // Niveau 2b : élément non-`String` ⇒ FILTRÉ (ordre relatif préservé).
        if (element is String) ids.add(element);
      }
      // Clé de section **verbatim** (opaque, `''` toléré). PAS de dédoublonnage
      // (verbatim) — les doublons sont neutralisés à l'APPLICATION par applyOrder.
      out['${entry.key}'] = ids;
    }
    // DW-ES24-1 : vue PROFONDE NON MODIFIABLE (idempotente ⇒ l'accesseur la rend
    // TELLE QUELLE, zéro-copie sur le chemin chaud — AC14).
    return zUnmodifiableMapOfLists(out);
  }

  /// Garde M3 pour une map **déjà typée** (voie [copyWith]) : rend une vue
  /// **PROFONDE NON MODIFIABLE** (map ET listes internes), ids **verbatim**.
  static Map<String, List<String>> _guardSectionOrders(
          Map<String, List<String>> raw) =>
      zUnmodifiableMapOfLists(<String, List<String>>{
        for (final entry in raw.entries) entry.key: <String>[...entry.value],
      });

  /// Encode le canal pour [toMap] : structure JSON **plate** (map de listes de
  /// `String`), toujours émise (même vide — idempotence).
  static Map<String, dynamic> _encodeSectionOrders(
          Map<String, List<String>> orders) =>
      <String, dynamic>{
        for (final entry in orders.entries) entry.key: <String>[...entry.value],
      };

  // ---------------------------------------------------------------------------
  // Slots AD-4 / clés réservées
  // ---------------------------------------------------------------------------

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZFolderContentsOrderExtensionParser? parser,
  ) {
    if (parser == null) return null;
    final map = _asStringMap(raw);
    if (map == null) return null;
    return ZExtension.guard<ZExtension?>(() => parser(map));
  }

  /// Clés persistées **RÉSERVÉES** (champ généré + `extension` + **canal
  /// [kSectionOrdersKey]** + **clés de sync `ZSyncMeta`**) — dérivées de
  /// `$ZFolderContentsOrderFieldSpecs` pour rester synchrones avec le codegen.
  ///
  /// 🔴 `...ZSyncMeta.reservedKeys` (AD-19.1) et [kSectionOrdersKey] (D3) sont
  /// **ESSENTIELS** : sans eux, `updated_at`/`is_deleted` (propriété du store) et
  /// la clé du canal atterriraient dans [extra] et seraient **réémis en double**
  /// par [toMap] (round-trip non idempotent, `==` cassée mémoire-vs-store).
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZFolderContentsOrderFieldSpecs) spec.name,
    'extension',
    kSectionOrdersKey,
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés **non réservées** de [map] (round-trip préservé) —
  /// **frontière d'ENTRÉE**. C'est [_sanitizeExtra], la garde **partagée**.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// 🔴 **LA GARDE PARTAGÉE DE `extra`** (ES-2.2b) — appelée par [fromMap] **et**
  /// [copyWith] (jamais divergentes). Délègue à [zSanitizeExtra] (`zcrud_core`,
  /// implémentation UNIQUE du repo).
  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFolderContentsOrder &&
          folderId == other.folderId &&
          _sectionOrdersEquals(sectionOrders, other.sectionOrders) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        folderId,
        _sectionOrdersHash(sectionOrders),
        extension,
        zJsonHash(extra),
      ]);

  /// Égalité D5 : **ensembliste sur les clés** de section (l'ordre des sections
  /// n'a aucun sens), **POSITIONNELLE dans chaque liste** (l'ordre EST le payload
  /// ⇒ `[a,b] != [b,a]`).
  static bool _sectionOrdersEquals(
    Map<String, List<String>> a,
    Map<String, List<String>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null && !b.containsKey(entry.key)) return false;
      if (other == null || !_listEquals(entry.value, other)) return false;
    }
    return true;
  }

  /// Hash D5 : **COMMUTATIF entre sections** (somme ⇒ indépendant de l'ordre des
  /// clés) mais **ORDRE-SENSIBLE dans une liste** (`Object.hashAll`). Ne PAS
  /// « corriger » le hash de liste en somme : l'ordre EST le payload.
  static int _sectionOrdersHash(Map<String, List<String>> m) {
    var acc = 0;
    for (final entry in m.entries) {
      acc = acc + Object.hash(entry.key, Object.hashAll(entry.value));
    }
    return acc;
  }
}

/// Comparaison **positionnelle** de deux listes (ordre-sensible).
bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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
