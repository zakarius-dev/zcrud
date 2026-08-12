/// Égalité et hachage **PROFONDS** de valeurs JSON — **l'unique implémentation du
/// dépôt pour le slot `extra`**.
///
/// **Portée EXACTE** : « unique » vaut **pour le slot `extra`** des entités
/// `ZExtensible`. `zcrud_core` conserve par ailleurs quelques `_mapEquals`/
/// `_mapHash` superficiels **locaux**, qui comparent des maps de
/// **configuration** (scalaires), **PAS** un slot `extra` extensible : ceux-ci
/// sont hors périmètre de cette primitive, sans risque de désynchronisation.
///
/// ## Pourquoi dans `zcrud_core` (AD-1)
///
/// Une entité `ZExtensible` compare son slot [ZExtensible.extra] avec une
/// égalité et un hash **profonds** : l'`==` natif d'une `Map`/`List` est une
/// égalité d'**IDENTITÉ** en Dart, qui échoue dès que `extra` porte du JSON
/// **IMBRIQUÉ** — ce qui est **sa raison d'être** (AD-4 pt.2 : maps/listes
/// legacy, documents Firestore). Sans cette primitive, deux décodages du
/// **même** payload donneraient `a == b ⇒ false`, `Set{a, b}.length ⇒ 2` :
/// toute déduplication, tout cache mémoïsé, tout `expect(relu, original)`
/// serait cassé.
///
/// Une primitive équivalente dupliquée dans plusieurs paquets satellites
/// créerait une **arête entre satellites** ⇒ **violation AD-1**. Elle est donc
/// hissée ici, dans le puits du graphe de dépendances ; un satellite qui
/// possédait sa propre variante peut la conserver comme **alias délégant**
/// vers celle-ci, en gardant sa surface publique **inchangée**.
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
