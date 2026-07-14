/// `ZNoteAudio` — slot audio **typé, versionné, OPT-IN** d'une note (ES-2.2,
/// **D6**, AD-4 pt.1).
///
/// ## 🔵 Le PREMIER `ZExtension` CONCRET du repo — un filet qu'on n'avait jamais
/// vu mordre
///
/// `grep -r "implements ZExtension" packages/*/lib` rendait **zéro** avant cette
/// story : AD-4 pt.1 (« slot type additif **versionné**, parsé **défensivement**,
/// **jamais** de throw ») n'avait **jamais été exercé concrètement** — c'était de
/// la **prose**. [fromJsonSafe] lui donne son premier cas réel **et** ses tests de
/// corruption (rétro ES-1, §7 : *« un filet qu'on n'a pas vu échouer n'est pas un
/// filet »*).
///
/// ## Pourquoi l'audio est HORS-SCHÉMA (FR-S5)
///
/// FR-S5 : *« Les champs audio (`audioUrl`/`audioPath`/`audioTextHash`) vivent en
/// `ZExtension`/`extra` ; une note sans audio se désérialise **sur le défaut** »*.
/// ⇒ [ZSmartNote] ne déclare **AUCUN** champ audio. **Deux voies**, les deux
/// supportées et testées :
///  1. **`extra`** (voie par défaut, **zéro code**) — une note dont le store porte
///     `audio_url`/`audio_path`/`audio_text_hash` **au top-level** voit ces clés
///     **inconnues** atterrir dans `extra` et **round-tripper** (AD-4 pt.2) ;
///  2. **`ZNoteAudio`** (voie **typée**, opt-in) — injectée via
///     `ZSmartNote.fromMap(map, extensionParser: ZNoteAudio.fromJsonSafe)`.
///
/// ## 🔴 Divergence de type RÉELLE (lex ↔ IFFD), trouvée sur disque
///
/// `audioTextHash` est **`String?`** chez lex (`smart_note.dart` l. 36) et
/// **`int?`** chez IFFD (`smart_note_model.dart` l. 11, décodé par
/// `int.tryParse(map['audioTextHash'].toString())`). ⇒ [textHash] **coerce**
/// défensivement `String` **OU** `num` vers `String?` — **jamais** de throw.
/// *(IFFD porte en plus `audioText: String?`, sans équivalent lex : il tombe dans
/// `extra` — cf. dette DW-ES22-2, due à l'adapter, ES-11.2.)*
///
/// ## Hors gate `reserved-keys` (et c'est correct)
///
/// `ZNoteAudio` n'est **ni `@ZcrudModel` ni `ZExtensible`** ⇒ hors `E_disk` /
/// `R_disk` ⇒ **AUCUN câblage `manual_probes.dart`** (même raisonnement que
/// `ZDocumentLearningInfo`, D3 d'ES-2.1 : l'y ajouter serait une erreur).
///
/// ## ⛔⛔ DW-ES14-2 — CE SLOT N'EST **JAMAIS TYPÉ** PAR LA VOIE DU REGISTRE
///
/// **En étant le premier `ZExtension` concret du repo, `ZNoteAudio` FALSIFIE la
/// clause d'échappement n°1 de DW-ES14-2** (`firebase_z_repository_impl.dart` :
/// *« si — et seulement si — **l'entité n'utilise pas le slot `extension`** »*). La
/// dette n'est **plus théorique** : elle porte désormais sur une entité **livrée**.
///
/// `registerZSmartNote` câble `fromMap: ZSmartNote.fromMap` — **sans**
/// `extensionParser` (le registre **n'offre aucun slot d'injection**) ⇒
/// `registry.decode('smart_note', map).extension` **n'est JAMAIS un `ZNoteAudio`**.
///
/// - **Donnée** : ✅ **PRÉSERVÉE** (remédiation MAJEUR-1/MAJEUR-2) — le payload non
///   typé est porté par `ZOpaqueNoteExtension` et **réémis VERBATIM**. *(Avant :
///   `extension == null` ⇒ `toMap()` **omettait la clé** ⇒ **le slot audio était
///   EFFACÉ du store au premier `put`**.)*
/// - **Type** : ⛔ **PERDU** sur cette voie — l'app **ne peut pas lire l'audio**.
///   Le correctif de fond (slot d'injection dans `ZcrudRegistry`) écrit
///   **`zcrud_core`** ⇒ **hors périmètre ES-2.2** (D9). **Épinglé en machine**
///   (`z_smart_note_test.dart` › groupe `DW-ES14-2`).
///
/// ⇒ **Câblage CORRECT (obligatoire tant que DW-ES14-2 n'est pas soldée)** :
///
/// ```dart
/// ZSmartNote.fromMap(map, extensionParser: ZNoteAudio.fromJsonSafe); // ✅ typé
/// ```
///
/// ## 🔴 Une version NON GÉRÉE rend `null` — **et le payload SURVIT quand même**
///
/// [fromJsonSafe] rend `null` sur une `format_version` inconnue (contrat AD-10 :
/// jamais de throw). **Ce `null` ne détruit plus rien** : `ZSmartNote` enveloppe
/// alors le payload dans un `ZOpaqueNoteExtension` qui le **réémet verbatim**
/// (MAJEUR-2 — sinon, une app **v1** relisant puis réécrivant une note écrite par
/// **v2** **effaçait le slot v2 du store**, définitivement).
library;

import 'package:zcrud_core/domain.dart';

/// Version du **sous-schéma** de [ZNoteAudio] — indépendante de celle de la note
/// (AD-4 pt.1). Une version **non gérée** fait rendre `null` à [ZNoteAudio.fromJsonSafe]
/// (jamais de throw) : la note **survit**, sans son slot audio **TYPÉ** — mais son
/// **payload BRUT est PRÉSERVÉ** (`ZOpaqueNoteExtension`, réémis **verbatim**) au
/// lieu d'être **effacé du store** à la réécriture (MAJEUR-2).
const int kZNoteAudioFormatVersion = 1;

/// Clé de la version dans la map `extension`.
const String kZNoteAudioFormatVersionKey = 'format_version';

/// Piste audio d'une note — **extension typée additive versionnée** (AD-4 pt.1).
class ZNoteAudio implements ZExtension {
  /// Construit une piste audio (tous les champs sont optionnels).
  const ZNoteAudio({this.url, this.path, this.textHash});

  /// URL distante de l'audio — `null` si non généré (lex : `audioUrl`).
  final String? url;

  /// Chemin local de l'audio (offline) — `null` si non téléchargé (lex :
  /// `audioPath`).
  final String? path;

  /// Hash du texte source de l'audio (**clé de cache**) — `null` si pas d'audio.
  ///
  /// Toujours une `String` **côté domaine**, même quand le store porte un
  /// **entier** (IFFD) : cf. [fromJsonSafe].
  final String? textHash;

  @override
  int get formatVersion => kZNoteAudioFormatVersion;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        kZNoteAudioFormatVersionKey: formatVersion,
        'url': url,
        'path': path,
        'text_hash': textHash,
      };

  /// Reconstruit **défensivement** une [ZNoteAudio] depuis sa map JSON, ou `null`
  /// (AD-4 pt.1 / AD-10) — **ne throw JAMAIS**.
  ///
  /// Rend `null` si [json] est : `null` · non-map · de `format_version` **absente**
  /// ou **non gérée** (`99`, `'x'`). Un champ **individuellement** corrompu (une
  /// `url` numérique, un `text_hash` qui est une liste) retombe sur `null`
  /// **sans** invalider les autres.
  ///
  /// [textHash] accepte **`String` (lex)** *et* **`num` (IFFD)** et rend toujours
  /// une `String?`.
  ///
  /// Bâtie sur [ZExtension.guard] : **toute** exception imprévue (donnée
  /// historique, tronquée, forgée) retombe sur `null` — le **parent survit
  /// toujours** à la désérialisation.
  static ZNoteAudio? fromJsonSafe(Object? json) =>
      ZExtension.guard<ZNoteAudio?>(() {
        final map = _asStringMap(json);
        if (map == null) return null;
        // Version NON GÉRÉE (ou absente) ⇒ `null`, jamais de throw : le slot est
        // ignoré, la note reste lisible (évolution additive, AD-10).
        if (map[kZNoteAudioFormatVersionKey] != kZNoteAudioFormatVersion) {
          return null;
        }
        return ZNoteAudio(
          url: _asString(map['url']),
          path: _asString(map['path']),
          textHash: _asTextHash(map['text_hash']),
        );
      });

  /// `String` telle quelle ; **tout autre type** ⇒ `null` (défensif).
  static String? _asString(Object? v) => v is String ? v : null;

  /// 🔴 Coercition de la **divergence lex ↔ IFFD** : `String` (lex) **ou** `num`
  /// (IFFD, `int?`) ⇒ `String?`. Tout le reste (`List`, `Map`, `bool`) ⇒ `null`.
  static String? _asTextHash(Object? v) {
    if (v is String) return v;
    if (v is num) return v.toString();
    return null;
  }

  /// Coerce défensive vers `Map<String, dynamic>` (repli `null`).
  ///
  /// 🔵 **L3** : le `try/catch` qui enveloppait la coercition des clés était **MORT**
  /// (l'interpolation `'${e.key}'` d'un `Object?` ne peut pas lever) — supprimé
  /// (R6 : aucun filet décoratif). La totalité reste garantie par
  /// [ZExtension.guard], qui enveloppe **tout** [fromJsonSafe].
  static Map<String, dynamic>? _asStringMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      return <String, dynamic>{for (final e in v.entries) '${e.key}': e.value};
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZNoteAudio &&
          url == other.url &&
          path == other.path &&
          textHash == other.textHash;

  @override
  int get hashCode => Object.hash(url, path, textHash);

  @override
  String toString() =>
      'ZNoteAudio(url: $url, path: $path, textHash: $textHash)';
}
