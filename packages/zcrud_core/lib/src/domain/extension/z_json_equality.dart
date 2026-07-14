/// Égalité et hachage **PROFONDS** de valeurs JSON — **l'unique implémentation du
/// repo pour le slot `extra`** (ES-2.2b / **DW-ES22-4**).
///
/// ⚠️ **Portée EXACTE** (LOW-1, code-review ES-2.2b — une dartdoc qui promet plus
/// que la machine ne tient est un finding) : « unique » vaut **pour le slot
/// `extra`** des entités `ZExtensible` (les 7 copies superficielles y sont
/// supprimées, et le harnais `reserved_keys_gate` l'EXIGE — assertion (i.2)).
/// Il subsiste dans `zcrud_core` **3** `_mapEquals`/`_mapHash` superficiels
/// locaux — `z_list_render_request.dart`, `z_sub_list_config.dart`,
/// `z_relation_field_widget.dart` — qui comparent des maps de **configuration**
/// (scalaires), **PAS** un slot `extra` : hors périmètre DW-ES22-4, aucun risque
/// de sync. Les rallier serait un nettoyage, pas une correction.
///
/// ## Pourquoi dans `zcrud_core` (AD-1)
///
/// Six entités `ZExtensible` — réparties dans **trois** satellites
/// (`zcrud_study_kernel`, `zcrud_document`, `zcrud_flashcard`) — comparaient leur
/// slot [ZExtensible.extra] avec un `_mapEquals`/`_mapHash` **SUPERFICIEL**,
/// **copié à l'identique** dans chaque fichier. Or l'`==` d'une `Map`/`List` est
/// une égalité d'**IDENTITÉ** en Dart : dès que `extra` porte du JSON
/// **IMBRIQUÉ** — ce qui est **sa raison d'être** (AD-4 pt.2 : maps/listes legacy
/// IFFD, documents Firestore) — deux décodages du **même** payload donnaient
/// `a == b ⇒ false`, `Set{a, b}.length ⇒ 2` : toute déduplication, tout cache
/// mémoïsé, tout `expect(relu, original)` était **cassé**.
///
/// Réutiliser `noteJsonEquals` (`zcrud_note`) depuis les trois autres satellites
/// aurait créé une **arête entre satellites** ⇒ **violation AD-1**. La primitive
/// est donc **hissée ici**, dans le puits du graphe ; `zcrud_note` conserve
/// `noteJsonEquals`/`noteJsonHash` en **alias délégants** (surface publique
/// **inchangée** — leçon `ZExportApi`, E11a-3).
///
/// ## Contrat
///
/// - `Map` : ordre des clés **NON** signifiant (hash par XOR, commutatif) ;
/// - `List` : ordre **signifiant** ;
/// - scalaires : `==` natif.
///
/// Les valeurs sont du **JSON** (issues d'un `jsonDecode` ou d'un store) : la
/// récursion **ne peut pas cycler**, aucun garde-fou de profondeur n'est requis.
library;

/// Égalité **PROFONDE** de deux valeurs JSON quelconques (`Map`/`List`/scalaire).
///
/// Cohérente avec [zJsonHash] : `zJsonEquals(a, b) ⇒ zJsonHash(a) == zJsonHash(b)`.
bool zJsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key)) return false;
      if (!zJsonEquals(e.value, b[e.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!zJsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Hash **PROFOND** cohérent avec [zJsonEquals] (ordre des clés d'une `Map`
/// **non** signifiant ; ordre d'une `List` **signifiant**).
int zJsonHash(Object? v) {
  if (v is Map) {
    // XOR : commutatif ⇒ insensible à l'ordre des clés (comme [zJsonEquals]).
    var h = 0;
    for (final e in v.entries) {
      h ^= Object.hash(e.key, zJsonHash(e.value));
    }
    return h;
  }
  if (v is List) {
    var h = 0;
    for (final e in v) {
      h = Object.hash(h, zJsonHash(e));
    }
    return h;
  }
  return v.hashCode;
}
