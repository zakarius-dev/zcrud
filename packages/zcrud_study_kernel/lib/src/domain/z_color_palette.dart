/// `ZColorPalette` — registre **borné et ordonné** de `colorKey` (`String`) +
/// remap déterministe d'une clé inconnue (ES-1.2, FR-S2, AC1/AC2).
///
/// **Frontière de pureté (SM-S5, D1)** : ce fichier **n'importe ni `dart:ui`,
/// ni `package:flutter/*`** et ne contient **aucun** type `Color`/`IconData` ni
/// littéral hexadécimal. Le kernel `zcrud_study_kernel` est pur-Dart (ses tests
/// tournent sous `dart test`) — la résolution `colorKey → Color` est un
/// **seam de présentation** ajouté dans `zcrud_core`
/// (`typedef ZColorKeyResolver = Color? Function(String key)` +
/// `ZcrudScope.colorKeyResolver`, jumeau strict du précédent
/// `ZAdornmentIconResolver`/`ZcrudScope.iconResolver`). Le domaine ne porte
/// jamais de couleur concrète : les apps/bindings résolvent une `colorKey` en
/// `Color` via ce seam, avec repli dérivé du `ColorScheme` courant (aucune
/// couleur codée en dur — AD-13/FR-26/NFR-S7).
///
/// **D2 — hash déterministe FNV-1a 32 bits pur-Dart** : le remap d'une clé
/// inconnue utilise [zFnv1a32] par défaut, **pas** `crypto`/SHA-256 (préserve
/// la fermeture transitive minimale du kernel, `{zcrud_core, zcrud_annotations}`
/// — NFR-S10/SM-S7 ; voir `z_kernel_resolution_test.dart`) et **pas**
/// `String.hashCode` (non déterministe entre versions/runs/plateformes du SDK
/// Dart — interdit). Le remap ne décide QUE du **slot de palette affiché**
/// pour une clé inconnue : la valeur persistée reste la `colorKey` brute
/// (aucune contrainte de parité byte-à-byte avec un hash externe). Une app qui
/// a besoin de parité avec un algorithme externe (ex. SHA-256 côté lex) peut
/// injecter son propre [ZKeyHash] sans que le kernel n'acquière de dépendance
/// crypto (AD-4 : extension par injection, jamais par héritage).
library;

import 'dart:convert';

/// Signature d'un algorithme de hash injectable pour [ZColorPalette.resolveKey]
/// (AD-4). Défaut : [zFnv1a32]. Permet à une app de substituer un algorithme
/// (ex. SHA-256) sans faire dépendre le kernel d'un package crypto.
typedef ZKeyHash = int Function(String key);

/// FNV-1a 32 bits sur les octets UTF-8 de [key] — déterministe
/// cross-run/cross-device/**web** (D2).
///
/// ---
/// ## ⛔ NE JAMAIS « SIMPLIFIER » LA MULTIPLICATION (avertissement mesuré, pas théorique)
///
/// La multiplication est **DÉCOMPOSÉE** en deux moitiés de 16 bits parce que
/// `hash * 16777619` dépasse 2^53 sur `dart2js` (les `int` y sont des `double`)
/// → **perte de précision → hash différent sur le web**.
///
/// Le piège est **vicieux** : la variante naïve
/// `hash = (hash * 0x01000193) & 0xFFFFFFFF` **passe 100 % des tests sur la
/// VM** (elle produit exactement les mêmes valeurs) et **diverge sur le web**.
/// Mesuré par compilation `dart2js` réelle + exécution sous Node (code-review
/// ES-1.2, axe 1) :
///
/// | Entrée     | décomposée (VM & JS) | naïve (VM)   | naïve (**JS**)      |
/// |------------|----------------------|--------------|---------------------|
/// | `'a'`      | `0xE40C292C`         | `0xE40C292C` | ❌ **`0xE40C2930`** |
/// | `'foobar'` | `0xBF9CF968`         | `0xBF9CF968` | ❌ **`0x06610426`** |
///
/// Un refactor « équivalent » est donc **invisible en local** : ce qui l'attrape
/// est le **gate JS** — les vecteurs golden de `test/z_color_palette_test.dart`
/// rejoués sur plateforme JavaScript par `dart test -p node` (script melos
/// `test:js`, enchaîné dans `melos run verify`). **Ne jamais retirer ce gate, ne
/// jamais réintroduire `dart:io` dans ce fichier de test** (il redeviendrait
/// non compilable en JS et le filet tomberait silencieusement).
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

/// Registre **borné et ordonné** de `colorKey` (`String`) + remap déterministe
/// d'une clé inconnue (AC1/AC2). **Zéro couleur** : le kernel ne porte que des
/// clés sémantiques `String` — la résolution concrète `colorKey → Color` vit
/// dans `zcrud_core` (`ZcrudScope.colorKeyResolver`).
///
/// Immuable, `const`-constructible, `==`/`hashCode` structurels.
class ZColorPalette {
  /// Construit une palette **injectable** — pas verrouillée aux clés d'une
  /// app particulière (lex/IFFD/DODLP portent chacune leurs propres clés).
  ///
  /// [keys] doit être **non vide** et contenir [fallbackKey] (garde-fou
  /// `assert` en debug ; en release, un `keys` vide ne fait jamais throw :
  /// [resolveKey] renvoie alors [fallbackKey] tel quel — AD-10). Constructeur
  /// **non-const** (l'assert `keys.contains(fallbackKey)` n'est pas une
  /// expression constante) — utiliser [ZColorPalette.defaultStudy] pour un
  /// jeu de clés `const`.
  ZColorPalette({
    required this.keys,
    required this.fallbackKey,
    this.hash = zFnv1a32,
  })  : assert(keys.isNotEmpty, 'ZColorPalette.keys ne doit pas être vide'),
        assert(
          keys.contains(fallbackKey),
          'ZColorPalette.fallbackKey doit appartenir à keys',
        );

  /// Jeu de clés **neutres** par défaut — aucune couleur, uniquement des clés
  /// sémantiques génériques réutilisables par n'importe quelle app study.
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

  /// Registre **ordonné** et **borné** de clés de palette (non vide).
  final List<String> keys;

  /// Clé de repli utilisée quand `raw` est `null`/vide (AC2).
  final String fallbackKey;

  /// Algorithme de hash **injectable** (AD-4) utilisé par [resolveKey] pour
  /// remapper une clé inconnue. Défaut : [zFnv1a32] (D2).
  final ZKeyHash hash;

  /// Repli **effectif** défensif (AD-10, finding L1 du code-review ES-1.2).
  ///
  /// Les `assert` du constructeur (`keys.contains(fallbackKey)`) sont **retirés
  /// en release** : une palette mal construite y survivrait silencieusement et
  /// [resolveKey] renverrait alors une clé **hors de [keys]** (violation de
  /// l'invariant AC2), avec un `indexOf` à `-1` → `RangeError` chez un
  /// consommateur UI faisant `colors[palette.indexOf(raw)]`.
  ///
  /// Garantie : si [keys] est **non vide**, le résultat appartient **toujours**
  /// à [keys] (repli sur `keys.first` si [fallbackKey] en est absent). Si [keys]
  /// est vide (état dégénéré, impossible en debug), [fallbackKey] est rendu tel
  /// quel — aucun throw.
  static String effectiveFallbackKey(List<String> keys, String fallbackKey) {
    if (keys.isEmpty) return fallbackKey;
    return keys.contains(fallbackKey) ? fallbackKey : keys.first;
  }

  /// Résout une `colorKey` **brute** (potentiellement `null`/vide/inconnue)
  /// vers une clé qui appartient **toujours** à [keys] (jamais de throw,
  /// jamais `null` — AD-10, AC2) :
  /// - [keys] vide (état dégénéré) → [fallbackKey] sans modulo (pas
  ///   d'`IntegerDivisionByZeroException`) — garde **en tête** ;
  /// - `raw == null || raw.isEmpty` → repli effectif ([effectiveFallbackKey],
  ///   défensif en release même si `fallbackKey ∉ keys`) ;
  /// - `raw` déjà dans [keys] → `raw` **tel quel** (le remap ne s'applique
  ///   qu'aux clés inconnues) ;
  /// - sinon → `keys[hash(raw) % keys.length]` — remap **déterministe**
  ///   (même entrée → même sortie, cross-run/cross-device/cross-plateforme ;
  ///   `%` par un diviseur positif rend en Dart un résultat **non négatif**,
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

  /// Index (dans [keys]) de la clé résolue de `raw` — utile aux consommateurs
  /// UI (ex. sélection d'une nuance dans une palette ordonnée, ou d'un slot de
  /// `ColorScheme` via `zColorSlotPair` côté `zcrud_core`).
  ///
  /// Défensif (AD-10, L1) : si [keys] est **non vide**, le résultat est
  /// **toujours** un index valide `0 ≤ i < keys.length` (jamais `-1`, donc
  /// jamais de `RangeError` en aval). `-1` **uniquement** si [keys] est vide —
  /// cas dégénéré où aucun index n'existe (indexer quoi que ce soit y
  /// throwerait de toute façon).
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
