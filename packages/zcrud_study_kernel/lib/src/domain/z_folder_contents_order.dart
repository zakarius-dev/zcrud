/// Ordre de contenu personnel d'un dossier d'étude `ZFolderContentsOrder`.
///
/// ## État personnel, jamais colocalisé avec le contenu partageable
///
/// L'ordre choisi par l'utilisateur (la liste ordonnée des ids d'items par
/// section) est strictement personnel : il ne vit jamais dans le sous-arbre
/// partageable du dossier (`ZStudyFolder`) — exactement comme l'état de
/// répétition espacée ne vit jamais dans la carte et l'état de lecture d'un
/// document jamais dans le document. Partager ou dupliquer un dossier
/// n'emporte donc jamais l'ordre personnel d'autrui. La non-colocation est
/// prouvée par machine (aucune clé d'ordre dans les spécifications de champ
/// du dossier, l'entité n'est jamais imbriquée dans `ZStudyFolder`). La
/// résolution de collection (où persister cet état) reste du ressort de
/// l'adaptateur backend, hors périmètre de ce kernel.
///
/// ## Pas un `ZEntity` : la clé d'identité est [folderId]
///
/// Jointure 1↔1 avec le dossier (même patron que l'état de lecture d'un
/// document, clé par identifiant de document) : aucun identifiant propre,
/// aucune réconciliation d'identifiant. La clé d'identité est [folderId].
///
/// ## [sectionOrders] est un canal hors-codegen
///
/// Le champ payload est un `Map<String, List<String>>` (`sectionKey → ordre
/// d'ids`). Le générateur zcrud ne supporte aucun type `Map` en champ codegen
/// — c'est le `Map` extérieur qui interdit le codegen (les `List<String>`
/// intérieures, elles, sont codegen-ables). Le canal entier est donc décodé/
/// réémis à la main, et sa clé [kSectionOrdersKey] est réservée — sans quoi
/// elle atterrirait aussi dans [extra] et serait émise deux fois (une par
/// `...extra`, une par le câblage manuel), cassant l'idempotence du
/// round-trip et l'égalité mémoire-vs-store.
///
/// Le seul `@ZcrudField` codegen-able est [folderId] (`String`).
///
/// ## Décodage défensif à deux niveaux + immuabilité profonde
///
/// Le canal a deux niveaux de corruption (le `Map` extérieur ET chaque
/// `List` intérieure), chacun avec sa garde (invariant AD-10, jamais de
/// `throw`) :
/// - `section_orders` absente / non-`Map` (`42`, `"x"`, une liste) ⇒ `{}` ;
/// - valeur de section non-`List` (`{"a": 7}`) ⇒ section ignorée ;
/// - élément non-`String` (`["a", 3, null]`) ⇒ élément filtré, ordre
///   relatif préservé (même tolérance que `tag_ids`) ;
/// - clés de section et ids verbatim (opaques, `''` toléré comme clé
///   opaque).
///
/// Immuabilité : la map exposée ET ses listes internes sont rendues non
/// modifiables en profondeur aux frontières qui la construisent ([fromMap],
/// [copyWith], décodage). Une mutation en place contournerait l'invariant,
/// changerait le [hashCode] et perdrait l'instance dans son propre `Set`.
///
/// Pas de dédoublonnage au stockage : l'ordre est préservé verbatim
/// (round-trip byte-stable) ; les doublons éventuels sont neutralisés à
/// l'application par [applyOrder] (1re occurrence gagne). Ne pas
/// « nettoyer » au décodage — ce serait une perte muette.
///
/// ## [applyTo] délègue à `applyOrder` — aucune primitive neuve
///
/// L'intégrité ordre↔contenu est portée gratuitement par [applyOrder] (déjà
/// total et défensif : id d'ordre sans item ignoré, item hors-ordre en
/// position déterministe, doublon d'ordre → 1re occurrence). Ce kernel ne
/// livre aucune primitive d'intégrité référentielle pour ce canal : la
/// réconciliation/purge (retirer d'un ordre les ids de contenu supprimés)
/// est du ressort du repository/de l'application hôte.
///
/// ## Égalité : ordre-sensible dans une liste, ordre-insensible entre sections
///
/// L'ordre est le payload : deux instances au même [folderId] dont une
/// section a sa liste inversée sont inégales (comparaison positionnelle des
/// listes, hash de liste ordre-sensible). Mais l'ordre des clés de la `Map`
/// n'a aucun sens : deux instances aux mêmes sections insérées dans un
/// ordre de clés différent sont égales (lookup ensembliste, hash extérieur
/// commutatif — somme sur les sections).
///
/// ## Zéro clé de synchronisation
///
/// Les clés réservées incluent celles de `ZSyncMeta` (`updated_at`,
/// `is_deleted`) : ces clés appartiennent au store (invariant AD-9),
/// l'entité étant persistée top-level, le store les écrit dans le corps
/// avant de passer la map complète à [fromMap]. Sans ce spread, elles
/// atterriraient dans [extra] et seraient réémises par [toMap].
///
/// Pur Dart — aucune dépendance Flutter/Firebase (invariant AD-1, ids
/// `String` neutres).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'apply_order.dart';

part 'z_folder_contents_order.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`
/// (invariant AD-4).
///
/// Fourni par l'application/le satellite (convention `X.fromJsonSafe`) et
/// injecté dans [ZFolderContentsOrder.fromMap] : le cœur ne connaît pas les
/// sous-classes concrètes. Toute exception est absorbée en `null` par
/// [ZExtension.guard].
typedef ZFolderContentsOrderExtensionParser = ZExtension? Function(
    Map<String, dynamic> json);

/// Clé persistée du canal hors-codegen [ZFolderContentsOrder.sectionOrders].
///
/// Déclarée une seule fois (top-level `const`, résolue par le gate de clés
/// réservées), consommée par [ZFolderContentsOrder.fromMap],
/// [ZFolderContentsOrder.toMap] et [ZFolderContentsOrder._reservedKeys] :
/// aucun littéral dupliqué.
const String kSectionOrdersKey = 'section_orders';

/// Ordre de contenu personnel d'un dossier — clé par [folderId] (pas un
/// `ZEntity`).
@ZcrudModel(kind: 'folder_contents_order')
class ZFolderContentsOrder with ZExtensible {
  /// Construit un ordre de contenu (constructeur `const`).
  ///
  /// Ne filtre et ne garde rien (`const` : ne peut appeler aucune fonction,
  /// l'invariant AD-10 y interdit l'`assert`). L'immuabilité profonde de
  /// [sectionOrders] est portée par les frontières qui construisent la map
  /// ([fromMap]/[copyWith]), et la garde de [extra] par l'accesseur.
  const ZFolderContentsOrder({
    this.folderId = '',
    Map<String, List<String>> sectionOrders = const <String, List<String>>{},
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // Un paramètre nommé ne peut pas être privé en Dart, mais les slots
    // bruts doivent rester privés — ce sont les accesseurs qui portent les
    // gardes (le `extra` normalisant, la vue immuable profonde de
    // `sectionOrders`).
    // ignore: prefer_initializing_formals
  })  : _sectionOrders = sectionOrders,
        // ignore: prefer_initializing_formals
        _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10) —
  /// ne lève jamais, pas même sur une map vide.
  ///
  /// Recopie le champ codegen ([folderId], via le décodeur généré —
  /// `folder_id` absent/non-`String` → `''`) puis câble les canaux
  /// hors-codegen : `section_orders` (décodage à deux niveaux + immuabilité
  /// profonde via [_decodeSectionOrders]), [extension] (repli `null`) et
  /// [extra] (clés non réservées).
  ///
  /// Ne délègue jamais nuement au décodeur généré (l'entité est
  /// `ZExtensible`) — elle peuple `extra` explicitement, ainsi que le canal
  /// `section_orders`.
  factory ZFolderContentsOrder.fromMap(
    Map<String, dynamic> map, {
    ZFolderContentsOrderExtensionParser? extensionParser,
  }) {
    final base = _$ZFolderContentsOrderFromMap(map);
    return ZFolderContentsOrder(
      folderId: base.folderId,
      // Canal hors-codegen — décodage défensif à deux niveaux.
      sectionOrders: _decodeSectionOrders(map[kSectionOrdersKey]),
      extension: _decodeExtension(map['extension'], extensionParser),
      extra: _extraFrom(map),
    );
  }

  /// Identité : le dossier dont c'est l'ordre de contenu (jointure 1↔1).
  /// Défaut `''`. Pas d'identifiant propre.
  @ZcrudField()
  final String folderId;

  /// Ordre personnel par section — canal hors-codegen : sa clé
  /// [kSectionOrdersKey] est réservée, il est décodé/réémis à la main.
  /// `sectionKey → [id, id, …]`.
  ///
  /// Non modifiable en profondeur inconditionnellement : l'accesseur rend
  /// une vue `unmodifiable` de la map ET de chaque liste interne — muter
  /// l'une ou l'autre lève `UnsupportedError`, même sur une instance née du
  /// constructeur `const` invoqué non-`const`. Sans quoi une mutation en
  /// place changerait le [hashCode] et perdrait l'instance dans son propre
  /// `Set`. Une section absente ⇒ aucun ordre (items rendus dans leur ordre
  /// d'entrée par [applyTo]).
  Map<String, List<String>> get sectionOrders =>
      zUnmodifiableMapOfLists(_sectionOrders);

  /// Slot brut tel que reçu par le constructeur — lu nulle part ailleurs
  /// que dans l'accesseur [sectionOrders] (le constructeur `const` ne peut
  /// pas le filtrer).
  final Map<String, List<String>> _sectionOrders;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  /// Hors-codegen.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}` (jamais
  /// `null`). Hors-codegen.
  ///
  /// Garde : l'accesseur normalise ([zNormalizeExtra]) — il ne rend jamais
  /// une clé réservée (dont [kSectionOrdersKey] et les clés de
  /// synchronisation), quelle que soit la voie d'écriture (y compris le
  /// constructeur `const`, seule voie incapable de filtrer). C'est le seul
  /// point que toutes les voies traversent ⇒ promesse inconditionnelle,
  /// sans `assert` ni `throw` (invariant AD-10).
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Slot `extra` brut tel que reçu par le constructeur — lu nulle part
  /// ailleurs que dans l'accesseur [extra] (ni `toMap`, ni `==`, ni
  /// `hashCode`).
  ///
  /// Il peut être pollué : le constructeur nominal est `const`, il ne peut
  /// appeler aucune fonction, et l'invariant AD-10 interdit l'`assert`.
  /// C'est l'accesseur qui porte la garde.
  final Map<String, dynamic> _extra;

  /// Sérialise vers la map persistée complète (snake_case), zéro-perte.
  ///
  /// Réutilise le `toMap()` généré ([folderId]) puis superpose les canaux
  /// hors-codegen : [extra] (l'accesseur normalisant), `section_orders`
  /// (toujours émis, même `{}` — round-trip idempotent) et [extension].
  ///
  /// Ne réémet ni clé de mise à jour ni clé de suppression logique : ces
  /// clés appartiennent au store (`ZSyncMeta`), pas au domaine (invariant
  /// AD-9) — garanti par construction (elles ne peuvent pas entrer dans
  /// [extra], donc ne peuvent pas en ressortir).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      // Étale l'accesseur (qui normalise), jamais le champ brut `_extra` :
      // c'est ce qui rend la promesse inconditionnelle, y compris pour une
      // instance née du constructeur nominal (`const` : il ne filtre
      // rien).
      ...extra,
      ...ZFolderContentsOrderZcrud(this).toMap(),
      // Canal hors-codegen — toujours émis (même `{}`) ⇒ idempotence.
      kSectionOrdersKey: _encodeSectionOrders(sectionOrders),
    };
    if (extension != null) {
      map['extension'] = extension!.toJson();
    }
    return map;
  }

  /// Copie à sentinelle — couvre tous les champs, y compris
  /// [sectionOrders], [extension] et [extra] (que le `copyWith` généré
  /// ignore ou remettrait à leurs défauts : perte silencieuse évitée ici).
  ///
  /// [sectionOrders] fourni est contrôlé (filtré en profondeur et rendu
  /// non modifiable) — une mutation applicative ne rouvre pas l'invariant
  /// que [fromMap] ferme.
  ZFolderContentsOrder copyWith({
    Object? folderId = _$undefined,
    Object? sectionOrders = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) =>
      ZFolderContentsOrder(
        folderId:
            identical(folderId, _$undefined) ? this.folderId : folderId as String,
        // La map fournie est rendue non modifiable en profondeur (la garde
        // vit aussi ici — une mutation applicative ne rouvre pas
        // l'invariant).
        sectionOrders: identical(sectionOrders, _$undefined)
            ? this.sectionOrders
            : _guardSectionOrders(sectionOrders as Map<String, List<String>>),
        extension: identical(extension, _$undefined)
            ? this.extension
            : extension as ZExtension?,
        // Même fonction nommée qu'en `fromMap` — `copyWith` ne peut pas
        // rouvrir le filtre des clés réservées.
        extra: identical(extra, _$undefined)
            ? this.extra
            : _sanitizeExtra(extra as Map<String, dynamic>),
      );

  /// Ordre mémorisé pour [sectionKey] (liste vide si aucun) — accès direct
  /// au canal, sans réordonner.
  List<String> orderFor(String sectionKey) =>
      sectionOrders[sectionKey] ?? const <String>[];

  /// Réordonne [items] selon l'ordre personnel de [sectionKey] en déléguant
  /// à [applyOrder] (jamais de tri réinventé).
  ///
  /// Fonction pure et totale : ordre partiel/permuté appliqué de façon
  /// stable, items absents de l'ordre placés en position déterministe
  /// ([unordered]), id d'ordre sans item ignoré, doublon d'ordre → 1re
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
  // Canal hors-codegen `section_orders` — décodage / encodage / garde
  // d'immuabilité.
  // ---------------------------------------------------------------------------

  /// Décode défensivement le canal à deux niveaux (invariant AD-10) —
  /// jamais de `throw`. Rend une map profondément non modifiable.
  static Map<String, List<String>> _decodeSectionOrders(Object? raw) {
    // Niveau 1 : le `Map` extérieur (`42`, `"x"`, une liste, absent) ⇒ `{}`.
    if (raw is! Map) return const <String, List<String>>{};
    final out = <String, List<String>>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      // Niveau 2a : valeur de section non-`List` ⇒ section ignorée.
      if (value is! List) continue;
      final ids = <String>[];
      for (final element in value) {
        // Niveau 2b : élément non-`String` ⇒ filtré (ordre relatif préservé).
        if (element is String) ids.add(element);
      }
      // Clé de section verbatim (opaque, `''` toléré). Pas de dédoublonnage
      // (verbatim) — les doublons sont neutralisés à l'application par applyOrder.
      out['${entry.key}'] = ids;
    }
    // Vue profonde non modifiable (idempotente ⇒ l'accesseur la rend telle
    // quelle, zéro-copie sur le chemin chaud).
    return zUnmodifiableMapOfLists(out);
  }

  /// Garde pour une map déjà typée (voie [copyWith]) : rend une vue
  /// profonde non modifiable (map ET listes internes), ids verbatim.
  static Map<String, List<String>> _guardSectionOrders(
          Map<String, List<String>> raw) =>
      zUnmodifiableMapOfLists(<String, List<String>>{
        for (final entry in raw.entries) entry.key: <String>[...entry.value],
      });

  /// Encode le canal pour [toMap] : structure JSON plate (map de listes de
  /// `String`), toujours émise (même vide — idempotence).
  static Map<String, dynamic> _encodeSectionOrders(
          Map<String, List<String>> orders) =>
      <String, dynamic>{
        for (final entry in orders.entries) entry.key: <String>[...entry.value],
      };

  // ---------------------------------------------------------------------------
  // Slots d'extension / clés réservées.
  // ---------------------------------------------------------------------------

  /// Décode défensivement l'extension via [parser] (repli `null`).
  static ZExtension? _decodeExtension(
    Object? raw,
    ZFolderContentsOrderExtensionParser? parser,
  ) {
    // Un hôte sans parser doit préserver verbatim ce qu'il n'a pas su
    // typer plutôt que le détruire au décodage : `extension` étant une clé
    // connue (donc exclue d'`extra`), un `null` inconditionnel effacerait
    // le payload d'un autre hôte avant toute ligne de code applicatif.
    return zDecodeExtension(raw, parser);
  }

  /// Clés persistées réservées (champ généré + `extension` + canal
  /// [kSectionOrdersKey] + clés de synchronisation) — dérivées des
  /// spécifications de champ générées pour rester synchrones avec le
  /// codegen.
  ///
  /// Le spread des clés de synchronisation et [kSectionOrdersKey] sont
  /// essentiels : sans eux, ces clés (propriété du store, ou clé du canal)
  /// atterriraient dans [extra] et seraient réémises en double par
  /// [toMap] (round-trip non idempotent, égalité cassée mémoire-vs-store).
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZFolderContentsOrderFieldSpecs) spec.name,
    'extension',
    kSectionOrdersKey,
    ...ZSyncMeta.reservedKeys,
  };

  /// Extrait `extra` = clés non réservées de [map] (round-trip préservé) —
  /// frontière d'entrée. C'est [_sanitizeExtra], la garde partagée.
  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      _sanitizeExtra(map);

  /// La garde partagée de `extra` — appelée par [fromMap] et [copyWith]
  /// (jamais divergentes). Délègue à [zSanitizeExtra] (`zcrud_core`,
  /// implémentation unique du dépôt).
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

  /// Égalité ensembliste sur les clés de section (l'ordre des sections n'a
  /// aucun sens), positionnelle dans chaque liste (l'ordre est le payload
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

  /// Hash commutatif entre sections (somme ⇒ indépendant de l'ordre des
  /// clés) mais ordre-sensible dans une liste (`Object.hashAll`). Ne pas
  /// « corriger » le hash de liste en somme : l'ordre est le payload.
  static int _sectionOrdersHash(Map<String, List<String>> m) {
    var acc = 0;
    for (final entry in m.entries) {
      acc = acc + Object.hash(entry.key, Object.hashAll(entry.value));
    }
    return acc;
  }
}

/// Comparaison positionnelle de deux listes (ordre-sensible).
bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
