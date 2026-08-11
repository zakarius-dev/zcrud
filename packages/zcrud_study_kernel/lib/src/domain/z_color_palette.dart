/// `ZColorPalette` — registre borné et ordonné de `colorKey` (`String`) +
/// remap déterministe d'une clé inconnue.
///
/// **Frontière de pureté** : ce fichier n'importe ni `dart:ui`, ni
/// `package:flutter/*`, et ne contient aucun type `Color`/`IconData` ni
/// littéral hexadécimal. Le kernel `zcrud_study_kernel` est pur-Dart (ses
/// tests tournent sous `dart test`) — la résolution `colorKey → Color` est
/// un seam de présentation fourni par `zcrud_core`
/// (`typedef ZColorKeyResolver = Color? Function(String key)` +
/// `ZcrudScope.colorKeyResolver`). Le domaine ne porte jamais de couleur
/// concrète : les applications/bindings résolvent une `colorKey` en `Color`
/// via ce seam, avec repli dérivé du `ColorScheme` courant (aucune couleur
/// codée en dur — invariant AD-13).
///
/// **Hash déterministe FNV-1a 32 bits pur-Dart** : le remap d'une clé
/// inconnue utilise [zFnv1a32] par défaut, jamais un algorithme
/// cryptographique (préserve la fermeture transitive minimale du kernel) ni
/// `String.hashCode` (non déterministe entre versions/exécutions/plateformes
/// du SDK Dart — interdit). Le remap ne décide que du slot de palette
/// affiché pour une clé inconnue : la valeur persistée reste la `colorKey`
/// brute (aucune contrainte de parité byte-à-byte avec un hash externe). Une
/// application qui a besoin de parité avec un algorithme externe peut
/// injecter son propre [ZKeyHash] sans que le kernel n'acquière de
/// dépendance cryptographique (invariant AD-4 : extension par injection,
/// jamais par héritage).
library;

import 'dart:convert';

/// Signature d'un algorithme de hash injectable pour
/// [ZColorPalette.resolveKey] (invariant AD-4). Défaut : [zFnv1a32]. Permet
/// à une application de substituer un algorithme sans faire dépendre le
/// kernel d'un paquet cryptographique.
typedef ZKeyHash = int Function(String key);

/// FNV-1a 32 bits sur les octets UTF-8 de [key] — déterministe entre
/// exécutions, appareils et **plateforme web**.
///
/// ---
/// ## Ne jamais « simplifier » la multiplication
///
/// La multiplication est décomposée en deux moitiés de 16 bits parce que
/// `hash * 16777619` dépasse la précision entière exacte sur `dart2js` (les
/// `int` y sont des `double`) → perte de précision → hash différent sur le
/// web.
///
/// Le piège est vicieux : la variante naïve
/// `hash = (hash * 0x01000193) & 0xFFFFFFFF` passe tous les tests sur la VM
/// (elle produit exactement les mêmes valeurs) et diverge sur le web. Mesuré
/// par compilation `dart2js` réelle et exécution sous Node :
///
/// | Entrée     | décomposée (VM & JS) | naïve (VM)   | naïve (JS)        |
/// |------------|----------------------|--------------|--------------------|
/// | `'a'`      | `0xE40C292C`         | `0xE40C292C` | `0xE40C2930` (divergent) |
/// | `'foobar'` | `0xBF9CF968`         | `0xBF9CF968` | `0x06610426` (divergent) |
///
/// Un refactor « équivalent » est donc invisible en local : ce qui l'attrape
/// est le rejeu des vecteurs golden de ce fichier sur plateforme JavaScript
/// (`dart test -p node`). Ne jamais retirer ce gate, ne jamais réintroduire
/// `dart:io` dans le fichier de test associé (il redeviendrait non
/// compilable en JS et le filet tomberait silencieusement).
/// ---
///
/// Vecteurs de test publiés (oracle indépendant de cette implémentation) :
/// `zFnv1a32('') == 0x811C9DC5`, `zFnv1a32('a') == 0xE40C292C`,
/// `zFnv1a32('foobar') == 0xBF9CF968`. Si un vecteur échoue, l'implémentation
/// est fausse — ne jamais ajuster le test pour le faire coller.
int zFnv1a32(String key) {
  var hash = 0x811c9dc5; // offset basis FNV-1a 32 bits.
  for (final byte in utf8.encode(key)) {
    hash ^= byte;
    // Multiplication décomposée 16/16 bits (JS-safe) — cf. dartdoc ci-dessus.
    final lo = (hash & 0xFFFF) * 0x01000193;
    final hi = ((hash >>> 16) * 0x01000193) & 0xFFFF;
    hash = (lo + (hi << 16)) & 0xFFFFFFFF;
  }
  return hash;
}

/// Registre borné et ordonné de `colorKey` (`String`) + remap déterministe
/// d'une clé inconnue. Zéro couleur : le kernel ne porte que des clés
/// sémantiques `String` — la résolution concrète `colorKey → Color` vit dans
/// `zcrud_core` (`ZcrudScope.colorKeyResolver`).
///
/// Immuable, `const`-constructible, `==`/`hashCode` structurels.
class ZColorPalette {
  /// Construit une palette injectable — pas verrouillée aux clés d'une
  /// application particulière.
  ///
  /// [keys] doit être non vide et contenir [fallbackKey] (garde-fou
  /// `assert` en debug ; en mode release, un `keys` vide ne fait jamais
  /// `throw` : [resolveKey] renvoie alors [fallbackKey] tel quel — invariant
  /// AD-10). Constructeur non-const (l'assert `keys.contains(fallbackKey)`
  /// n'est pas une expression constante) — utiliser
  /// [ZColorPalette.defaultStudy] pour un jeu de clés `const`.
  ZColorPalette({
    required this.keys,
    required this.fallbackKey,
    this.hash = zFnv1a32,
  })  : assert(keys.isNotEmpty, 'ZColorPalette.keys ne doit pas être vide'),
        assert(
          keys.contains(fallbackKey),
          'ZColorPalette.fallbackKey doit appartenir à keys',
        );

  /// Jeu de clés neutres par défaut — aucune couleur, uniquement des clés
  /// sémantiques génériques réutilisables par n'importe quelle application
  /// d'étude.
  const ZColorPalette.defaultStudy()
      : keys = const <String>[
          'primary',
          'secondary',
          'tertiary',
          'success',
          'warning',
          'danger',
          'info',
          'neutral',
        ],
        fallbackKey = 'neutral',
        hash = zFnv1a32;

  /// Registre ordonné et borné de clés de palette (non vide).
  final List<String> keys;

  /// Clé de repli utilisée quand `raw` est `null`/vide.
  final String fallbackKey;

  /// Algorithme de hash injectable (invariant AD-4) utilisé par
  /// [resolveKey] pour remapper une clé inconnue. Défaut : [zFnv1a32].
  final ZKeyHash hash;

  /// Repli effectif défensif (invariant AD-10).
  ///
  /// Les `assert` du constructeur (`keys.contains(fallbackKey)`) sont
  /// retirés en mode release : une palette mal construite y survivrait
  /// silencieusement et [resolveKey] renverrait alors une clé hors de
  /// [keys], avec un `indexOf` à `-1` → `RangeError` chez un consommateur UI
  /// faisant `colors[palette.indexOf(raw)]`.
  ///
  /// Garantie : si [keys] est non vide, le résultat appartient toujours à
  /// [keys] (repli sur `keys.first` si [fallbackKey] en est absent). Si
  /// [keys] est vide (état dégénéré, impossible en debug), [fallbackKey] est
  /// rendu tel quel — aucun `throw`.
  static String effectiveFallbackKey(List<String> keys, String fallbackKey) {
    if (keys.isEmpty) return fallbackKey;
    return keys.contains(fallbackKey) ? fallbackKey : keys.first;
  }

  /// Résout une `colorKey` brute (potentiellement `null`/vide/inconnue)
  /// vers une clé qui appartient toujours à [keys] (jamais de `throw`,
  /// jamais `null` — invariant AD-10) :
  /// - [keys] vide (état dégénéré) → [fallbackKey] sans modulo (pas de
  ///   `IntegerDivisionByZeroException`) — garde en tête ;
  /// - `raw == null || raw.isEmpty` → repli effectif
  ///   ([effectiveFallbackKey], défensif en release même si `fallbackKey ∉
  ///   keys`) ;
  /// - `raw` déjà dans [keys] → `raw` tel quel (le remap ne s'applique
  ///   qu'aux clés inconnues) ;
  /// - sinon → `keys[hash(raw) % keys.length]` — remap déterministe (même
  ///   entrée → même sortie, entre exécutions, appareils et plateformes ;
  ///   `%` par un diviseur positif rend en Dart un résultat non négatif,
  ///   y compris si un [ZKeyHash] injecté renvoie un entier négatif).
  String resolveKey(String? raw) {
    if (keys.isEmpty) return fallbackKey;
    if (raw == null || raw.isEmpty) {
      return effectiveFallbackKey(keys, fallbackKey);
    }
    if (keys.contains(raw)) return raw;
    final index = hash(raw) % keys.length;
    return keys[index];
  }

  /// Index (dans [keys]) de la clé résolue de `raw` — utile aux
  /// consommateurs UI (ex. sélection d'une nuance dans une palette ordonnée,
  /// ou d'un slot de `ColorScheme` côté `zcrud_core`).
  ///
  /// Défensif (invariant AD-10) : si [keys] est non vide, le résultat est
  /// toujours un index valide `0 ≤ i < keys.length` (jamais `-1`, donc
  /// jamais de `RangeError` en aval). `-1` uniquement si [keys] est vide —
  /// cas dégénéré où aucun index n'existe (indexer quoi que ce soit y
  /// lèverait de toute façon).
  int indexOf(String? raw) {
    if (keys.isEmpty) return -1;
    final index = keys.indexOf(resolveKey(raw));
    // `resolveKey` garantit un élément de `keys` quand `keys` est non vide ;
    // ceinture + bretelles pour le cas release dégradé.
    return index < 0 ? 0 : index;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZColorPalette &&
          runtimeType == other.runtimeType &&
          _listEquals(keys, other.keys) &&
          fallbackKey == other.fallbackKey &&
          hash == other.hash;

  @override
  int get hashCode => Object.hash(Object.hashAll(keys), fallbackKey, hash);

  @override
  String toString() =>
      'ZColorPalette(keys: $keys, fallbackKey: $fallbackKey)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
